# Smart Energy Meter - Quick Start Guide

## Prerequisites

- Docker and Docker Compose installed
- Python 3.8+ installed
- At least 8GB RAM available

---

## Setup Steps

### Step 1: Initial Setup (One-Time)

Run the setup script to initialize all services:

```bash
cd "Smart Energy Meter"
./initial-setup.sh
```

This will:
- Start all Docker containers (Kafka, PostgreSQL, MinIO, Trino, dbt, Superset, Redis)
- Create master data tables (customers & devices)
- Install Python dependencies

**Wait 2-3 minutes** for all services to fully initialize.

---

### Step 2: Populate Initial Historical Data (Optional but Recommended)

Generate historical data for the past few days:

```bash
python3 telemetry_simulator_hist.py
```

This populates historical telemetry data, useful for creating meaningful dashboards immediately.

---

### Step 3: Start Real-time Telemetry Simulator

Generate live smart meter data and send to Kafka:

```bash
python3 telemetry_simulator.py
```

Leave this running to continuously generate telemetry data.

**Optional**: Run the log simulator for unstructured health logs:

```bash
python3 log_simulator.py
```

---

### Step 4: Process Data with dbt (Automatic)

dbt runs automatically every 10 minutes to process Kafka messages into Iceberg tables.

**Monitor processing**:
```bash
docker logs -f dbt-transformations
```

**Manual run** (optional):
```bash
docker exec -it dbt-transformations dbt run
```

---

### Step 5: Visualize with Apache Superset

1. **Access**: http://localhost:8088
2. **Login**:
   - Username: `admin`
   - Password: `admin123`
3. **Explore data** in SQL Lab or create dashboards

See [SUPERSET_SETUP.md](SUPERSET_SETUP.md) for detailed dashboard creation guide.

---

## Service URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| **Apache Superset** | http://localhost:8088 | admin / admin123 |
| **Kafka UI** | http://localhost:8080 | None |
| **Trino Web UI** | http://localhost:8081 | None |
| **MinIO Console** | http://localhost:9001 | minio / minio123 |
| **PostgreSQL** | localhost:5432 | smartenergymeter / smartenergymeter123 |

---

## Quick Troubleshooting

### Services Not Starting

```bash
# Check service status
docker-compose ps

# View logs for specific service
docker logs <container-name>

# Restart all services
docker-compose restart
```

### No Data in Kafka

```bash
# Check if simulator is running
ps aux | grep telemetry_simulator

# View Kafka messages
docker exec kafka-kraft kafka-console-consumer \
  --topic telemetry_raw \
  --bootstrap-server localhost:9092 \
  --from-beginning \
  --max-messages 5
```

### Trino "Server Still Initializing"

Wait 2-3 minutes after startup, then retry.

### dbt Models Failing

```bash
# Test dbt connection
docker exec -it dbt-transformations dbt debug

# Run with full refresh
docker exec -it dbt-transformations dbt run --full-refresh
```

### Superset Connection Issues

```bash
# Check if Trino is running
curl http://localhost:8081/v1/info

# Restart Superset
docker restart superset
```

---

## Clean Up

Stop all services and remove data:

```bash
docker-compose down -v
```

Restart fresh:

```bash
./initial-setup.sh
```

---

For detailed information, see [README.md](README.md)
