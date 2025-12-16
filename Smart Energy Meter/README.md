# Use Case: Smart Energy Meter – Usage & Health Analytics
This PoC will simulate smart energy meters sending telemetry data and will:

1. Calculate electricity usage per customer based on meter telemetry.
2. Monitor and report on the health of energy meters using fault logs and operational metrics.

## Data Types Involved:
1. Structured: Customer and device master data
2. Semi-structured: Simulated telemetry data from smart meters (JSON)
3. Unstructured: Energy meter fault logs (text)

## Proposed Open-Source Technology Stack:
1. Kafka – Streaming ingestion of real-time telemetry data
2. PostgreSQL – Storage of customer and device master data
3. Trino – SQL query layer across data sources and parquet-based analytics storage
4. dbt – Transformation and modeling (ETL/ELT) layer for curated analytics datasets

The objective of this PoC is to demonstrate a Databricks-equivalent lakehouse-style architecture using only open-source components, aligned to our IoT use cases and future data platform strategy.

---

# Telemetry Simulator

## Overview

The telemetry simulator generates realistic smart energy meter data and publishes it to Kafka topic `telemetry_raw`.

## Files

- `telemetry_simulator.py` - Producer that generates and sends telemetry messages
- `telemetry_consumer.py` - Consumer that reads and displays messages
- `requirements.txt` - Python dependencies
- `docker-compose.yml` - Kafka infrastructure setup

## Quick Start

### 1. Run Initial Setup (First Time Only)

The initial setup script will:
- Clean up any existing containers and volumes
- Start all services (Kafka, PostgreSQL, MinIO, Trino, dbt)
- Create and populate customer and device master data tables

```bash
./initial-setup.sh
```

### 2. Install Python Dependencies

```bash
pip install -r requirements.txt
```

Or using a virtual environment (recommended):

```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Run the Telemetry Simulator

The simulator now reads device and customer mappings from PostgreSQL master data tables.

```bash
python3 telemetry_simulator.py
```

**Expected Output:**
```
================================================================================
Smart Energy Meter Telemetry Simulator
================================================================================
Topic: telemetry_raw
Kafka: ['localhost:19092']
Message Interval: 2s
================================================================================

Loading device-customer mappings from PostgreSQL...
✓ Loaded 10 active devices from PostgreSQL
Devices: 10 | Customers: 5

✓ Connected to Kafka at ['localhost:19092']

Device-Customer Mapping:
  MTR-10000 -> CUST-8000
  MTR-10001 -> CUST-8000
  MTR-10002 -> CUST-8001
  MTR-10003 -> CUST-8001
  ...

Starting telemetry simulation... (Press Ctrl+C to stop)
--------------------------------------------------------------------------------
✓ Sent: MTR-10291 | Energy: 0.42 kWh | Voltage: 229.6V | Status: OK | Partition: 1
✓ Sent: MTR-10293 | Energy: 1.85 kWh | Voltage: 235.2V | Status: OK | Partition: 0
```

### 4. View Messages (Optional)

view in Kafka UI: http://localhost:8080

## Message Format

Each telemetry message includes:

```json
{
  "device_id": "MTR-10291",
  "customer_id": "CUST-8831",
  "timestamp": "2025-12-09T06:25:40Z",
  "metrics": {
    "energy_kwh": 0.42,
    "voltage": 229.6,
    "battery_pct": 78
  },
  "status": "OK"
}
```

## Configuration

Edit `telemetry_simulator.py` to customize:

```python
NUM_DEVICES = 10              # Number of simulated meters
NUM_CUSTOMERS = 5             # Number of customers
MESSAGE_INTERVAL = 2          # Seconds between messages
KAFKA_BOOTSTRAP_SERVERS = ['localhost:19092']
TOPIC_NAME = 'telemetry_raw'
```

## Kafka UI

Access the Kafka UI at: http://localhost:8080

Navigate to:
- **Topics** → `telemetry_raw` to see message counts and partitions
- **Messages** → View actual message content

## Useful Kafka Commands

### List all topics
```bash
docker exec kafka-kraft kafka-topics --list --bootstrap-server localhost:9092
```

### Describe topic
```bash
docker exec kafka-kraft kafka-topics --describe \
  --topic telemetry_raw \
  --bootstrap-server localhost:9092
```

### View messages from beginning
```bash
docker exec kafka-kraft kafka-console-consumer \
  --topic telemetry_raw \
  --bootstrap-server localhost:9092 \
  --from-beginning \
  --max-messages 10
```

### Check consumer group status
```bash
docker exec kafka-kraft kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --describe \
  --group telemetry-consumer-group
```

## Troubleshooting

### Connection refused error
- Ensure Kafka is running: `docker ps`
- Check Kafka logs: `docker logs kafka-kraft`
- Verify port 19092 is accessible

### Topic not found
- The topic will be auto-created on first message
- Or create it manually using the command above

### No messages appearing
- Check producer is running and sending messages
- Verify consumer is connected to correct topic
- Check Kafka UI at http://localhost:8080

## Next Steps

After generating telemetry data, you can:

1. **Store in PostgreSQL** - Customer and device master data
2. **Process with Trino** - Query and analyze across data sources
3. **Transform with dbt** - Create curated analytics datasets
4. **Monitor health** - Analyze fault logs and operational metrics

---

# dbt Transformations

## Overview

The dbt project handles data transformations for the Smart Energy Meter POC, ingesting data from Kafka and creating analytics-ready datasets in Iceberg.

## Architecture

```
Kafka (telemetry_raw)
  → dbt staging (stg_telemetry_raw)
  → dbt marts (device_daily_metrics, customer_usage_summary)
  → Iceberg Tables in MinIO
```

## Project Structure

```
dbt-project/
├── dbt_project.yml          # Project configuration
├── profiles.yml             # Trino connection profile
├── packages.yml             # dbt dependencies
├── models/
│   ├── staging/
│   │   ├── sources.yml      # Source definitions (Kafka)
│   │   └── stg_telemetry_raw.sql  # Staging model (incremental)
│   └── marts/
│       ├── device_daily_metrics.sql      # Daily device analytics
│       └── customer_usage_summary.sql    # Customer aggregations
├── Dockerfile               # dbt container image
└── entrypoint.sh           # Container startup script
```

## Models

### Staging Layer

#### `stg_telemetry_raw`
- **Materialization**: Incremental table
- **Source**: kafka.default.telemetry_raw
- **Target**: iceberg.staging.stg_telemetry_raw
- **Purpose**: Ingest raw telemetry from Kafka, convert timestamps, add surrogate keys
- **Incremental Strategy**: Only processes new messages based on timestamp

### Marts Layer

#### `device_daily_metrics`
- **Materialization**: Table
- **Purpose**: Daily aggregated metrics per device
- **Metrics**:
  - Total energy consumption (kWh)
  - Average/min/max voltage
  - Average battery percentage
  - Reading count
  - Warning count
  - Health score percentage
  - Device health status (HEALTHY/DEGRADED/UNHEALTHY)

#### `customer_usage_summary`
- **Materialization**: Table
- **Purpose**: Customer-level usage and health summary
- **Metrics**:
  - Daily total energy consumption
  - Average voltage across all devices
  - Active device count
  - Total warnings
  - Average device health
  - Customer alert status (NORMAL/MONITOR/ACTION_REQUIRED)

## Execution Modes

The dbt container supports two execution modes:

### Automatic Mode (Default - Enabled)

Container automatically runs `dbt run` every 10 minutes in a loop.

**Good for**: Production-like testing, continuous processing

**Current setting**: `DBT_AUTO_RUN: "true"` (enabled by default)

**Monitor processing**:
```bash
docker logs -f dbt-transformations
```

### Manual Mode

Container stays running, you execute `dbt run` when needed.

**Good for**: Development, testing, debugging

**Disable auto-run**: Edit `docker-compose.yml`:
```yaml
environment:
  DBT_AUTO_RUN: "false"      # Disable automatic runs
  DBT_RUN_INTERVAL: "600"    # (ignored when disabled)
```

Then restart:
```bash
docker-compose up -d dbt
```

**Manual execution**:
```bash
docker exec -it dbt-transformations dbt run
```

## Running dbt Models

### Run All Models

```bash
docker exec -it dbt-transformations dbt run
```

### Run Specific Model

```bash
# Run staging only
docker exec -it dbt-transformations dbt run --select staging

# Run marts only
docker exec -it dbt-transformations dbt run --select marts

# Run specific model
docker exec -it dbt-transformations dbt run --select stg_telemetry_raw
```

### Incremental Refresh

```bash
# Full refresh (rebuild from scratch)
docker exec -it dbt-transformations dbt run --full-refresh

# Incremental update (only new data)
docker exec -it dbt-transformations dbt run --select stg_telemetry_raw
```

## Querying Results

### Via Trino CLI

```bash
# Connect to Trino
docker exec -it trino-coordinator trino

# Query staging table
SELECT * FROM iceberg.staging.stg_telemetry_raw LIMIT 10;

# Query daily metrics
SELECT * FROM iceberg.marts.device_daily_metrics
WHERE reading_date = CURRENT_DATE;

# Query customer summary
SELECT * FROM iceberg.marts.customer_usage_summary
WHERE customer_alert_status != 'NORMAL';
```

### Via Trino Web UI

Access: http://localhost:8081

Navigate to Query Editor and run:
```sql
SHOW SCHEMAS FROM iceberg;
SHOW TABLES FROM iceberg.staging;
SHOW TABLES FROM iceberg.marts;
```

## Data Lineage

```
Sources:
  kafka.default.telemetry_raw (Kafka topic)

Staging:
  iceberg.staging.stg_telemetry_raw
    ← kafka.default.telemetry_raw

Marts:
  iceberg.marts.device_daily_metrics
    ← iceberg.staging.stg_telemetry_raw

  iceberg.marts.customer_usage_summary
    ← iceberg.marts.device_daily_metrics
```

## Troubleshooting

### Issue: dbt can't connect to Trino

**Solution**: Verify Trino is running and healthy
```bash
docker ps | grep trino
curl http://localhost:8081/v1/info
```

### Issue: Models fail with "schema does not exist"

**Solution**: Create schemas manually in Trino
```sql
CREATE SCHEMA IF NOT EXISTS iceberg.staging;
CREATE SCHEMA IF NOT EXISTS iceberg.marts;
```

### Issue: Incremental model not detecting new data

**Solution**: Check Kafka topic has new messages
```bash
docker exec -it dbt-transformations dbt run --select stg_telemetry_raw --full-refresh
```

### Issue: Parquet files not appearing in MinIO

**Solution**: Verify Iceberg configuration and S3 endpoint
```bash
# Check MinIO buckets
docker exec minio-storage mc ls minio/lakehouse/

# Verify Trino can write to MinIO
docker logs trino-coordinator | grep -i minio
```

---

## EC2 Deployment

For deploying Kafka to AWS EC2, see [EC2-DEPLOYMENT.md](EC2-DEPLOYMENT.md)