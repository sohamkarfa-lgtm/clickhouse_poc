-- ============================================================
-- ClickHouse Cluster — Schema Setup
-- Run this ONCE, manually, after the cluster is healthy:
--
--   docker exec -i ch-node-01 clickhouse-client \
--     --user=dev_user --password=dev_password \
--     --multiquery < init_scripts/01_init.sql
--
-- ON CLUSTER propagates each statement to all 4 nodes via
-- the distributed DDL queue (Keeper-coordinated).
-- ============================================================

-- 1. Database — created on all nodes
CREATE DATABASE IF NOT EXISTS ch_poc ON CLUSTER ch_cluster;

-- 2. Local table — ReplicatedMergeTree
--    {shard} and {replica} are substituted from each node's macros.xml
--    Shard 1 (node-01, node-02) -> path .../1/sensor_events_local
--    Shard 2 (node-03, node-04) -> path .../2/sensor_events_local
CREATE TABLE IF NOT EXISTS ch_poc.sensor_events_local ON CLUSTER ch_cluster
(
    event_time   DateTime64(3),
    device_id    LowCardinality(String),
    location     LowCardinality(String),
    metric       LowCardinality(String),
    value        Float64,
    unit         LowCardinality(String)
)
ENGINE = ReplicatedMergeTree(
    '/clickhouse/tables/{shard}/sensor_events_local',
    '{replica}'
)
PARTITION BY toYYYYMM(event_time)
ORDER BY (device_id, metric, event_time)
TTL toDateTime(event_time) + INTERVAL 1 YEAR;

-- 3. Distributed table — the entry point for inserts and queries
--    Lives on every node, routes to the right shard via rand()
CREATE TABLE IF NOT EXISTS ch_poc.sensor_events ON CLUSTER ch_cluster
(
    event_time   DateTime64(3),
    device_id    LowCardinality(String),
    location     LowCardinality(String),
    metric       LowCardinality(String),
    value        Float64,
    unit         LowCardinality(String)
)
ENGINE = Distributed(
    'ch_cluster',           -- cluster name (from cluster.xml)
    'ch_poc',                -- target database
    'sensor_events_local',    -- target local table
    rand()                    -- shard key: random distribution
);

-- 4. Seed data — insert via the Distributed table
--    ClickHouse will spread these across both shards
INSERT INTO ch_poc.sensor_events
SELECT
    now() - toIntervalSecond(rand() % 604800)  AS event_time,
    concat('device-', leftPad(toString(rand() % 20 + 1), 3, '0')) AS device_id,
    ['warehouse-A','warehouse-B','factory-1','factory-2'][(rand() % 4) + 1] AS location,
    ['temperature','humidity','pressure','vibration'][(rand() % 4) + 1] AS metric,
    round(20 + (rand() % 80), 2) AS value,
    ['°C','%','hPa','mm/s'][(rand() % 4) + 1] AS unit
FROM numbers(10000);

-- 5. Verify
SELECT 'Total rows (via Distributed)' AS check, count() AS value FROM ch_poc.sensor_events;