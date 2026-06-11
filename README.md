ClickHouse Cluster — ClickHouse POC

A fully containerised ClickHouse cluster for infrastructure and database testing.

## Architecture

| Layer | Details |
|---|---|
| Shards | 2 shards |
| Replicas | 2 replicas per shard (4 ClickHouse nodes total) |
| Coordination | 3 ClickHouse Keeper nodes |
| Table engine | ReplicatedMergeTree |
| Entry point | Distributed table |

## What this tests

- Replication between replicas within a shard
- Sharding — data split across shard 1 and shard 2
- Distributed tables — single insert/query entry point
- Failover — cluster continues when a node goes down

## Port Map

| Container | HTTP | TCP | Keeper |
|---|---|---|---|
| ch-node-01 (shard1, replica1) | 8123 | 9000 | — |
| ch-node-02 (shard1, replica2) | 8124 | 9001 | — |
| ch-node-03 (shard2, replica1) | 8125 | 9002 | — |
| ch-node-04 (shard2, replica2) | 8126 | 9003 | — |
| keeper-01 | — | — | 9181 |
| keeper-02 | — | — | 9182 |
| keeper-03 | — | — | 9183 |

## Prerequisites

- Docker Engine (inside WSL2)
- Docker Compose plugin
- Python 3 + venv (for data generator)
- Git

## Quick Start (for new developers)

```bash
# 1. Clone
git clone https://github.com/sohamkarfa-lgtm/clickhouse_poc.git
cd clickhouse_poc

# 2. Configure
cp .env.example .env

# 3. Start
docker compose up -d

# 4. Verify
docker compose ps
```

## Developer Commands

```bash
# Start full cluster
docker compose up -d

# Check all container health
docker compose ps

# Connect to node-01
docker exec -it ch-node-01 clickhouse-client --user=dev_user --password=dev_password

# Stop one node (failover test)
docker compose stop ch-node-01

# Wipe everything and start fresh
docker compose down -v

# View logs for a specific node
docker compose logs -f ch-node-01
```
## WSL2 Setup Note — Docker DNS Fix (Required)

If containers can't resolve each other's hostnames (e.g. `keeper-01`, `ch-node-01`)
and you see errors like `Cannot resolve any of provided ZooKeeper hosts due to DNS error`,
WSL2's `/etc/resolv.conf` is overriding Docker's embedded DNS.

**Fix (one-time, per machine):**

```bash
sudo mkdir -p /etc/docker
echo '{
  "dns": ["8.8.8.8", "1.1.1.1"]
}' | sudo tee /etc/docker/daemon.json

sudo service docker restart
```

Verify it worked:
```bash
docker exec ch-node-01 getent hosts keeper-01
# should return an IP address, not empty
```

## Failover Testing
```bash
# Stop a replica — Distributed queries still work
docker compose stop ch-node-02
docker exec ch-node-01 clickhouse-client --user=dev_user --password=dev_password \
  --query "SELECT count() FROM datasets.hits_v1"
docker compose start ch-node-02

# Stop a Keeper node — quorum (2/3) holds
docker compose stop keeper-03
docker exec ch-node-01 clickhouse-client --user=dev_user --password=dev_password \
  --query "SELECT * FROM system.zookeeper_connection"
docker compose start keeper-03
```