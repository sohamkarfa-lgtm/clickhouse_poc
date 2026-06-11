-- ============================================================
-- Demo Queries — ClickBench dataset
-- ============================================================

-- 1. Total rows across both shards (Distributed)
SELECT count() FROM datasets.hits_v1;

-- 2. Per-shard local row counts (run on each node individually)
SELECT count() FROM datasets.hits_v1_local;

-- 3. Cluster topology + health
SELECT
    cluster, shard_num, replica_num, host_name,
    is_local, errors_count, slowdowns_count
FROM system.clusters
WHERE cluster = 'ch_cluster'
ORDER BY shard_num, replica_num;

-- 4. Active Keeper session
SELECT host, port, is_expired, session_uptime_elapsed_seconds
FROM system.zookeeper_connection;

-- 5. Replication queue status (any pending sync operations?)
SELECT
    database, table, replica_name,
    is_currently_executing, num_tries,
    last_exception
FROM system.replication_queue
LIMIT 20;

-- 6. Replicated table overall status
SELECT
    database, table, is_leader, is_readonly,
    absolute_delay, queue_size, log_pointer, log_max_index
FROM system.replicas
WHERE database = 'datasets';

-- 7. ClickBench-style query: top 10 URLs by hit count
SELECT
    URL,
    count() AS hits
FROM datasets.hits_v1
WHERE URL != ''
GROUP BY URL
ORDER BY hits DESC
LIMIT 10;

-- 8. ClickBench-style: hits + visits joined by date (the official test query)
SELECT
    EventDate,
    hits,
    visits
FROM
(
    SELECT EventDate, count() AS hits
    FROM datasets.hits_v1
    GROUP BY EventDate
) ANY LEFT JOIN
(
    SELECT StartDate AS EventDate, sum(Sign) AS visits
    FROM datasets.visits_v1
    GROUP BY EventDate
) USING EventDate
ORDER BY hits DESC
LIMIT 10
SETTINGS joined_subquery_requires_alias = 0;

-- 9. Query performance — recent query log
SELECT
    left(query, 80) AS query_preview,
    round(query_duration_ms / 1000.0, 3) AS duration_sec,
    formatReadableSize(memory_usage) AS memory,
    read_rows
FROM system.query_log
WHERE type = 'QueryFinish'
  AND query_start_time >= now() - INTERVAL 1 HOUR
ORDER BY query_start_time DESC
LIMIT 20;

-- 10. Storage / compression per table
SELECT
    table,
    formatReadableSize(sum(data_compressed_bytes))   AS compressed,
    formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed,
    round(sum(data_uncompressed_bytes) / sum(data_compressed_bytes), 1) AS ratio,
    sum(rows) AS total_rows
FROM system.parts
WHERE database = 'datasets' AND active = 1
GROUP BY table;
