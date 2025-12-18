# Smart Energy Meter - Quick Start Guide

## Complete Setup & Data Flow

### Step 1: Initial Setup (One-Time)

Run the setup script to initialize everything:

```bash
cd "Smart Energy Meter"
./initial-setup.sh
```

This will:
- Clean up and start all Docker containers
- Create master data tables (customers & devices)
- Install Python dependencies

**Wait 2-3 minutes** for all services to fully initialize (especially Trino).

---

### Step 2: Start Telemetry Simulator

Generate smart meter data and send to Kafka:

```bash
python3 telemetry_simulator.py
```

**Expected Output:**
```
================================================================================
Smart Energy Meter Telemetry Simulator
================================================================================
Loading device-customer mappings from PostgreSQL...
✓ Loaded 10 active devices from PostgreSQL
Devices: 10 | Customers: 5

✓ Connected to Kafka at ['localhost:19092']

Device-Customer Mapping:
  MTR-10000 -> CUST-8000
  MTR-10001 -> CUST-8000
  ...

Starting telemetry simulation...
✓ Sent: MTR-10000 | Energy: 1.23 kWh | Voltage: 232.1V | Status: OK
```

Leave this running to continuously generate data.

---

### Step 3: Process Data with dbt

**Auto-run is enabled by default** - dbt runs automatically every 10 minutes to process Kafka messages.

#### Monitor dbt Processing

```bash
# View dbt logs in real-time
docker logs -f dbt-transformations
```

#### Manual Run (Optional)

You can trigger dbt manually anytime:

```bash
docker exec -it dbt-transformations dbt run
```

#### Disable Auto-run

To switch to manual-only mode, edit `docker-compose.yml`:

```yaml
environment:
  DBT_AUTO_RUN: "false"      # Disable automatic runs
  DBT_RUN_INTERVAL: "600"    # (ignored when auto-run is false)
```

Then restart:

```bash
docker-compose up -d dbt
```

**What this does:**
1. **Staging**: Reads from `kafka.default.telemetry_raw` → writes to `iceberg.staging.stg_telemetry_raw`
2. **Marts**: Transforms staging data → creates `device_daily_metrics` and `customer_usage_summary`

**Expected Output:**
```
Running with dbt=1.7.0
Found 3 models, 0 tests, 0 snapshots...

Completed successfully

Done. PASS=3 WARN=0 ERROR=0 SKIP=0 TOTAL=3
```

---

### Step 4: Query the Data

#### Option A: Trino CLI

```bash
docker exec -it trino-coordinator trino
```

Then run queries:

```sql
-- Show all catalogs
SHOW CATALOGS;

-- View Kafka raw data
SELECT * FROM kafka.default.telemetry_raw LIMIT 10;

-- View staged data in Iceberg
SELECT * FROM iceberg.energy_data_staging.stg_telemetry_raw LIMIT 10;

-- View daily device metrics
SELECT * FROM iceberg.energy_data_marts.device_daily_metrics;

-- View customer usage summary
SELECT * FROM iceberg.energy_data_marts.customer_usage_summary;

-- Join with master data
SELECT
    t.device_id,
    d.device_model,
    d.location,
    c.customer_name,
    t.energy_kwh,
    t.voltage,
    t.status
FROM iceberg.energy_data_staging.stg_telemetry_raw t
JOIN postgresql.public.device_master d ON t.device_id = d.device_id
JOIN postgresql.public.customer_master c ON t.customer_id = c.customer_id
LIMIT 10;
```

#### Option B: Trino Web UI

1. Open browser: http://localhost:8081
2. Navigate to Query Editor
3. Run SQL queries from above

---

## Data Flow Architecture

```
┌─────────────────┐
│ PostgreSQL      │ Master Data (customers, devices)
│ Tables:         │
│ - customer_mast│
│ - device_master│
└────────┬────────┘
         │
         │ (Loaded by)
         │
┌────────▼────────┐
│ telemetry_sim   │ Python script
│                 │ Reads: device-customer mappings
│                 │ Generates: Smart meter readings
└────────┬────────┘
         │
         │ (Publishes to)
         │
┌────────▼────────┐
│ Kafka           │ Topic: telemetry_raw
│ Broker (KRaft)  │ Format: JSON messages
└────────┬────────┘
         │
         │ (Read by)
         │
┌────────▼────────┐
│ dbt Models      │ Running in dbt container
│                 │
│ Staging:        │ stg_telemetry_raw (incremental)
│   Source: kafka.default.telemetry_raw
│   Dest: iceberg.staging.stg_telemetry_raw
│                 │
│ Marts:          │ device_daily_metrics
│   Aggregates:   customer_usage_summary
└────────┬────────┘
         │
         │ (Writes to)
         │
┌────────▼────────┐
│ Iceberg Tables  │ Stored in MinIO as Parquet
│ in MinIO        │ Metadata in PostgreSQL
│                 │
│ Buckets:        │ - lakehouse (data files)
│                 │ - telemetry (backup)
└─────────────────┘
```

---

## Troubleshooting

### Kafka Messages Not Showing

**Problem**: `SELECT * FROM kafka.default.telemetry_raw` returns empty

**Solutions**:
1. Check telemetry simulator is running: `ps aux | grep telemetry`
2. Check Kafka topic has messages:
   ```bash
   docker exec kafka-kraft kafka-console-consumer \
     --topic telemetry_raw \
     --bootstrap-server localhost:9092 \
     --from-beginning \
     --max-messages 5
   ```
3. Check Kafka UI: http://localhost:8080

### Trino "Server Still Initializing"

**Problem**: Trino queries fail with "SERVER_STARTING_UP"

**Solution**: Wait 2-3 minutes after `docker-compose up`, then retry

### dbt Models Fail

**Problem**: `dbt run` shows errors

**Solutions**:
1. Check Trino is running: `curl http://localhost:8081/v1/info`
2. Test dbt connection: `docker exec -it dbt-transformations dbt debug`
3. Create schemas manually:
   ```sql
   CREATE SCHEMA IF NOT EXISTS iceberg.staging;
   CREATE SCHEMA IF NOT EXISTS iceberg.marts;
   ```

### No Data in Iceberg Tables

**Problem**: Iceberg tables are empty after `dbt run`

**Solutions**:
1. Ensure Kafka has messages (see above)
2. Run dbt with full refresh: `docker exec -it dbt-transformations dbt run --full-refresh`
3. Check dbt logs for errors

---

## Service URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Kafka UI | http://localhost:8080 | None |
| Trino Web UI | http://localhost:8081 | None |
| MinIO Console | http://localhost:9001 | minio / minio123 |
| Kafka Bootstrap | localhost:19092 | None |
| PostgreSQL | localhost:5432 | smartenergymeter / smartenergymeter123 |

---

## Scheduled Processing (Optional)

To continuously process Kafka messages:

### Option 1: Cron Job

```bash
# Add to crontab (run dbt every 10 minutes)
*/10 * * * * docker exec dbt-transformations dbt run >> /var/log/dbt-run.log 2>&1
```

### Option 2: Manual Loop

```bash
while true; do
  docker exec dbt-transformations dbt run
  sleep 600  # 10 minutes
done
```

---

## Clean Up

To stop all services and remove data:

```bash
docker-compose down -v
```

To restart fresh:

```bash
./initial-setup.sh
```
