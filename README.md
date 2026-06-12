# ClickHouse Distributed Cluster POC

A fully containerized ClickHouse cluster for testing distributed database architecture, replication, sharding, and failover scenarios.

## 📋 Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Port Map](#port-map)
- [Databases & Tables](#databases--tables)
- [Developer Commands](#developer-commands)
- [Common Tasks](#common-tasks)
- [Troubleshooting](#troubleshooting)

---

## 🏗️ Architecture

This POC demonstrates a production-like ClickHouse cluster with:

| Component | Configuration |
|---|---|
| **Shards** | 2 shards |
| **Replicas** | 2 replicas per shard (4 ClickHouse nodes total) |
| **Coordination Layer** | 3 ClickHouse Keeper nodes |
| **Replication Engine** | ReplicatedMergeTree |
| **Query Entry Point** | Distributed tables |

### What Gets Tested

✅ **Replication** — Data synchronization between replicas within a shard  
✅ **Sharding** — Data distribution across shard 1 and shard 2  
✅ **Distributed Queries** — Single entry point for queries across all shards  
✅ **Failover** — Cluster resilience when a node goes down  
✅ **Data Consistency** — Keeper-coordinated DDL execution across the cluster  

---

## 📦 Prerequisites

- **Docker Engine** (v20.10+)
- **Docker Compose Plugin** (v2.0+)
- **Git**
- **4GB RAM minimum** for the cluster
- *WSL2 users*: See [WSL2 Docker DNS Fix](#wsl2-docker-dns-fix-required) if containers can't communicate

---

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/sohamkarfa-lgtm/clickhouse_poc.git
cd clickhouse_poc
cp .env.example .env
```

Update `.env` before startup if you want to override the default ClickHouse credentials.
The `CLICKHOUSE_USER` / `CLICKHOUSE_PASSWORD` and `CLICKHOUSE_READONLY_USER` / `CLICKHOUSE_READONLY_PASSWORD` values are used by both the node user config and the cluster replica credentials in `config/cluster.xml.tpl`.

### 2. Start the Cluster

```bash
docker compose up -d
```

### 3. Verify All Containers Are Running

```bash
docker compose ps
```

Expected output shows 7 healthy containers:
- `keeper-01`, `keeper-02`, `keeper-03` (Keeper nodes)
- `ch-node-01` through `ch-node-04` (ClickHouse nodes)

### 4. Initialize the Database Schema

Run the initialization script on the cluster:

```bash
docker exec -i ch-node-01 clickhouse-client \
  --user=dev_user --password=dev_password \
  --multiquery < init_scripts/01_init.sql
```

### 5. (Optional) Load ClickBench Datasets

For testing with realistic data:

```bash
docker exec -i ch-node-01 clickhouse-client \
  --user=dev_user --password=dev_password \
  --multiquery < init_scripts/02_load_clickbench.sql
```

---

## 🔌 Port Map

| Container | Purpose | HTTP | TCP | Keeper |
|---|---|---|---|---|
| `ch-node-01` | Shard 1, Replica 1 | 8123 | 9000 | — |
| `ch-node-02` | Shard 1, Replica 2 | 8124 | 9001 | — |
| `ch-node-03` | Shard 2, Replica 1 | 8125 | 9002 | — |
| `ch-node-04` | Shard 2, Replica 2 | 8126 | 9003 | — |
| `keeper-01` | Coordination | — | — | 9181 |
| `keeper-02` | Coordination | — | — | 9182 |
| `keeper-03` | Coordination | — | — | 9183 |

**Access from host machine:** `localhost:8123` (or respective port for each node)

---

## 📊 Databases & Tables

### Database: `ch_poc`

Custom POC database for testing:

- **`sensor_events_local`** — Local replicated table (shard-specific)
- **`sensor_events`** — Distributed table (queries all shards)
- **Schema:** event_time, device_id, location, metric, value, unit

### Database: `datasets`

Pre-loaded ClickBench datasets for realistic workloads:

- **`hits_v1_local`** & **`hits_v1`** — Website analytics hits (84M rows)
- **`visits_v1_local`** & **`visits_v1`** — Website visits (10M rows)

---

## 🛠️ Developer Commands

### Connect to a Node

```bash
# Connect to node-01 (shard 1, replica 1)
docker exec -it ch-node-01 clickhouse-client \
  --user=dev_user --password=dev_password

# Or any other node
docker exec -it ch-node-03 clickhouse-client \
  --user=dev_user --password=dev_password
```

### View Cluster Status

```bash
# Check all containers
docker compose ps

# View detailed logs
docker compose logs -f ch-node-01

# Check a specific node's health
docker exec ch-node-01 clickhouse-client \
  --user=dev_user --password=dev_password \
  --query "SELECT * FROM system.clusters"
```

### Manage the Cluster

```bash
# Start the entire cluster
docker compose up -d

# Stop the cluster (data persists)
docker compose stop

# Restart a single node
docker compose restart ch-node-01

# Stop a single node (for failover testing)
docker compose stop ch-node-01

# Wipe everything and start fresh (⚠️ deletes data)
docker compose down -v

# View real-time logs
docker compose logs -f ch-node-01
```

---

## 📝 Common Tasks

### Test Replication

```bash
# 1. Insert data into node-01
docker exec -i ch-node-01 clickhouse-client \
  --user=dev_user --password=dev_password << EOF
INSERT INTO ch_poc.sensor_events VALUES 
  (now(), 'device-001', 'warehouse', 'temperature', 22.5, 'celsius');
EOF

# 2. Query from node-02 (replica) to confirm replication
docker exec -i ch-node-02 clickhouse-client \
  --user=dev_user --password=dev_password \
  --query "SELECT COUNT() FROM ch_poc.sensor_events_local"
```

### Query Distributed Table

```bash
# Query goes to all nodes via the distributed entry point
docker exec -i ch-node-01 clickhouse-client \
  --user=dev_user --password=dev_password \
  --query "SELECT shard_num, COUNT() FROM ch_poc.sensor_events GROUP BY shard_num"
```

### Simulate Node Failure

```bash
# Stop node-01
docker compose stop ch-node-01

# Queries still work via failover (hitting node-02, node-03, node-04)
docker exec -i ch-node-02 clickhouse-client \
  --user=dev_user --password=dev_password \
  --query "SELECT COUNT() FROM ch_poc.sensor_events"

# Restart the failed node
docker compose start ch-node-01
```

### Monitor Query Performance

```bash
# Check query logs
docker exec ch-node-01 clickhouse-client \
  --user=dev_user --password=dev_password \
  --query "SELECT query, duration_ms FROM system.query_log LIMIT 10"

# Check table sizes
docker exec ch-node-01 clickhouse-client \
  --user=dev_user --password=dev_password \
  --query "SELECT database, table, rows, bytes_on_disk FROM system.tables WHERE database != 'system'"
```

---

## ⚙️ Troubleshooting

### ❌ Containers Won't Start

```bash
# Check Docker daemon status
docker --version

# Check logs for the failed container
docker compose logs ch-node-01

# Clean up and retry
docker compose down -v
docker compose up -d
```

### ❌ Nodes Can't Find Each Other (DNS Error)

Error: `Cannot resolve any of provided ZooKeeper hosts due to DNS error`

**Solution:** See [WSL2 Docker DNS Fix](#wsl2-docker-dns-fix-required)

### ❌ Port Already in Use

```bash
# Find what's using the port
lsof -i :8123

# Or use Docker to find conflicting containers
docker ps --all

# Stop conflicting containers or change ports in docker-compose.yml
```

### ❌ Data Not Replicating

```bash
# Verify Keeper is healthy
docker exec keeper-01 bash -c 'echo ruok | nc localhost 9181'

# Check replication status on a node
docker exec -i ch-node-01 clickhouse-client \
  --user=dev_user --password=dev_password \
  --query "SELECT * FROM system.replication_queue"

# Check cluster definition
docker exec -i ch-node-01 clickhouse-client \
  --user=dev_user --password=dev_password \
  --query "SELECT * FROM system.clusters WHERE cluster = 'ch_cluster'"
```

### ❌ Query Hangs or Times Out

```bash
# Check active queries
docker exec -i ch-node-01 clickhouse-client \
  --user=dev_user --password=dev_password \
  --query "SELECT query, elapsed FROM system.processes"

# Set query timeout (300 seconds)
docker exec -i ch-node-01 clickhouse-client \
  --user=dev_user --password=dev_password \
  --query_timeout=300 \
  --query "SELECT * FROM datasets.hits_v1 LIMIT 1000000"
```

---

## 🔧 WSL2 Docker DNS Fix (Required)

If running on WSL2 and containers can't resolve each other's hostnames:

**Symptom:** Errors like `Cannot resolve any of provided ZooKeeper hosts due to DNS error`

**Root Cause:** WSL2's `/etc/resolv.conf` overrides Docker's embedded DNS

**Fix (one-time per machine):**

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "dns": ["8.8.8.8", "1.1.1.1"]
}
EOF

sudo service docker restart
```

**Verify the fix worked:**

```bash
docker exec ch-node-01 getent hosts keeper-01
# Should return an IP address, not empty
```

---

## 📚 Project Structure

```
clickhouse_poc/
├── docker-compose.yml          # Cluster orchestration
├── config/
│   ├── cluster.xml.tpl         # ClickHouse cluster definition
│   ├── users.xml.tpl           # User credentials & permissions
    ├── render-config.sh        # Contains the renderer
    ├── keeper0X
    │   └── keeper.xml          # ClickHouse keeper configuration
│   └── node0X/                 # Per-node configurations
│       ├── macros.xml          # Shard/replica macros
│       └── server.xml          # Node-specific settings
├── init_scripts/
│   ├── 01_init.sql             # POC Schema setup
│   └── 02_load_clickbench.sql  # Sample data loading
├── datasets/
│   ├── hits_sample.tsv         # Sample hits data
│   └── visits_sample.tsv       # Sample visits data
├── sample_queries
│   └──queries.sql              # POC demo queries
├── .env                        # docker compose automatically loads from the repo root
├── .gitignore
└── README.md                   # This file

```

---

## 💡 Tips for Developers

- **Testing Failover?** Stop a node with `docker compose stop ch-node-01`, then run queries from other nodes
- **Checking Replication?** Insert on one node, query on its replica using the `_local` table
- **Performance Testing?** Use `datasets.hits_v1` (84M rows) for realistic workloads
- **Debugging Issues?** Check container logs: `docker compose logs -f service_name`
- **Fresh Start?** Use `docker compose down -v` to wipe all data and volumes

---

## 📖 Further Reading

- [ClickHouse Documentation](https://clickhouse.com/docs)
- [ClickHouse Cluster Guide](https://clickhouse.com/docs/en/architecture/replication)
- [Keeper Coordination](https://clickhouse.com/docs/en/guides/keeper-setup)

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