# Use Case: Smart Energy Meter – Usage & Health Analytics

This PoC will simulate smart energy meters sending telemetry data and will:

1. Calculate electricity usage per customer based on meter telemetry.
2. Monitor and report on the health of energy meters using fault logs and operational metrics.

---

## Data Types Involved

1. **Structured**: Customer and device master data (PostgreSQL tables)
2. **Semi-structured**: Simulated telemetry data from smart meters (JSON messages in Kafka)
3. **Unstructured**: Energy meter fault logs (plain text logs)

---

## Proposed Open-Source Technology Stack

1. **Apache Kafka** – Streaming ingestion of real-time telemetry data
2. **PostgreSQL** – Storage of customer and device master data
3. **MinIO** – Object storage for Iceberg tables (S3-compatible)
4. **Trino** – SQL query layer across data sources and distributed query engine
5. **dbt** – Transformation and modeling (ELT) layer for curated analytics datasets
6. **Apache Superset** – Visualization, charts & dashboards
7. **Redis** – Caching layer for Superset

---

## Objective

The objective of this PoC is to demonstrate a **Databricks-equivalent lakehouse-style architecture** using only open-source components, aligned to IoT use cases and future data platform strategy.

This architecture showcases:
- Real-time data ingestion from IoT devices
- Multi-source data federation (Kafka, PostgreSQL, Object Storage)
- Scalable data transformations with dbt
- Interactive analytics and visualization with Superset

---

## Quick Start

See **[QUICKSTART.md](QUICKSTART.md)** for step-by-step setup instructions.

**TL;DR:**
```bash
# 1. Run initial setup
./initial-setup.sh

# 2. Start telemetry simulator
python3 telemetry_simulator.py

# 3. Access Superset for visualization
# Open http://localhost:8088 (admin / admin123)
```

---

# Telemetry Simulator

## Overview

The telemetry simulator generates realistic smart energy meter data and publishes it to Kafka topic `telemetry_raw`.

## Simulators Available

| Simulator | Purpose | Kafka Topic | Data Format |
|-----------|---------|-------------|-------------|
| [telemetry_simulator.py](telemetry_simulator.py) | Real-time structured telemetry | `telemetry_raw` | JSON |
| [telemetry_simulator_hist.py](telemetry_simulator_hist.py) | Historical data generation | `telemetry_raw` | JSON |

## Running the Simulator

### Prerequisites

Install Python dependencies (already executed via intial-setup script):
```bash
pip install -r requirements.txt
```

Or using a virtual environment (recommended):
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### Start Telemetry Simulator

```bash
python3 telemetry_simulator.py
```

The simulator reads device and customer mappings from PostgreSQL master data tables and generates realistic meter readings.

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
  ...

Starting telemetry simulation... (Press Ctrl+C to stop)
--------------------------------------------------------------------------------
✓ Sent: MTR-10291 | Energy: 0.42 kWh | Voltage: 229.6V | Status: OK | Partition: 1
✓ Sent: MTR-10293 | Energy: 1.85 kWh | Voltage: 235.2V | Status: OK | Partition: 0
```


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

Edit [telemetry_simulator.py](telemetry_simulator.py) to customize:

```python
NUM_DEVICES = 10              # Number of simulated meters
NUM_CUSTOMERS = 5             # Number of customers
MESSAGE_INTERVAL = 2          # Seconds between messages
KAFKA_BOOTSTRAP_SERVERS = ['localhost:19092']
TOPIC_NAME = 'telemetry_raw'
```

## Viewing Messages

### Kafka UI
Access the Kafka UI at: http://localhost:8080

Navigate to:
- **Topics** → `telemetry_raw` to see message counts and partitions
- **Messages** → View actual message content

### Command Line

```bash
# View messages from beginning
docker exec kafka-kraft kafka-console-consumer \
  --topic telemetry_raw \
  --bootstrap-server localhost:9092 \
  --from-beginning \
  --max-messages 10
```

---

# Trino - Distributed Query Engine

## Overview

Trino provides a unified SQL interface to query data across multiple sources (Kafka, PostgreSQL, Iceberg) without moving data.

## Architecture Role

Trino acts as the **federation layer** that:
- Queries Kafka topics in real-time
- Accesses PostgreSQL master data
- Reads/writes Iceberg tables in MinIO
- Joins data across different sources

## Access Trino

### Web UI
- **URL**: http://localhost:8081
- Navigate to Query Editor to run SQL queries
- View query execution plans and performance metrics

### CLI

```bash
# Connect to Trino
docker exec -it trino-coordinator trino
```

## Key Catalogs

| Catalog | Purpose | Example Usage |
|---------|---------|---------------|
| `kafka` | Stream Kafka topics | `SELECT * FROM kafka.default.telemetry_raw` |
| `postgresql` | Master data tables | `SELECT * FROM postgresql.public.customer_master` |
| `iceberg` | Analytics tables | `SELECT * FROM iceberg.marts.device_daily_metrics` |

## Example Queries

### Query Kafka Stream
```sql
-- View raw telemetry from Kafka
SELECT * FROM kafka.default.telemetry_raw LIMIT 10;
```

### Query Master Data
```sql
-- View customer information
SELECT * FROM postgresql.public.customer_master;

-- View device information
SELECT * FROM postgresql.public.device_master;
```

### Query Iceberg Tables
```sql
-- View staging data
SELECT * FROM iceberg.staging.stg_telemetry_raw LIMIT 10;

-- View hourly device metrics
SELECT * FROM iceberg.marts.device_hourly_metrics
WHERE reading_date = CURRENT_DATE
ORDER BY reading_hour DESC;

-- View daily device metrics
SELECT * FROM iceberg.marts.device_daily_metrics
WHERE reading_date = CURRENT_DATE;

-- View monthly device metrics
SELECT * FROM iceberg.marts.device_monthly_metrics
WHERE reading_month = DATE_TRUNC('month', CURRENT_DATE);

-- View customer daily usage
SELECT * FROM iceberg.marts.customer_daily_usage_summary
WHERE reading_date = CURRENT_DATE;

-- View customer monthly usage
SELECT * FROM iceberg.marts.customer_monthly_usage_summary
WHERE reading_month = DATE_TRUNC('month', CURRENT_DATE);

-- View customer month-to-date with projections
SELECT * FROM iceberg.marts.customer_usage_mtd_summary
WHERE mtd_alert_status != 'NORMAL';
```

### Cross-Source Join
```sql
-- Join telemetry with master data
SELECT
    t.device_id,
    d.device_model,
    d.location,
    c.customer_name,
    t.energy_kwh,
    t.voltage,
    t.status
FROM iceberg.staging.stg_telemetry_raw t
JOIN postgresql.public.device_master d ON t.device_id = d.device_id
JOIN postgresql.public.customer_master c ON t.customer_id = c.customer_id
LIMIT 10;
```

## Configuration

Trino catalogs are configured in [trino-config/catalog/](trino-config/catalog/):
- `kafka.properties` - Kafka connector configuration
- `postgresql.properties` - PostgreSQL connector
- `iceberg.properties` - Iceberg connector with MinIO backend

---

# dbt - Data Transformation Layer

## Overview

dbt (data build tool) transforms raw data from Kafka into curated analytics datasets stored as Iceberg tables in MinIO.

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

## dbt Models

### Staging Layer

#### `stg_telemetry_raw`
- **Materialization**: Incremental table
- **Source**: `kafka.default.telemetry_raw`
- **Target**: `iceberg.staging.stg_telemetry_raw`
- **Purpose**: Ingest raw telemetry from Kafka, convert timestamps, add surrogate keys
- **Incremental Strategy**: Only processes new messages based on timestamp

### Marts Layer

The marts layer provides multiple time-grain aggregations for flexible analytics:

#### Device-Level Metrics

##### `device_hourly_metrics`
- **Materialization**: Table
- **Granularity**: Hourly per device
- **Purpose**: Hourly aggregated metrics with deduplication
- **Metrics**:
  - Total energy consumption per hour (kWh)
  - Avg/min/max voltage
  - Average battery percentage
  - Reading count, warning count, OK count
  - Health score percentage
  - Device health status (HEALTHY/DEGRADED/UNHEALTHY)
- **Additional Fields**: `reading_hour`, `reading_date`, `hour_of_day`

##### `device_daily_metrics`
- **Materialization**: Table
- **Granularity**: Daily per device
- **Purpose**: Daily aggregated metrics per device
- **Metrics**:
  - Total energy consumption per day (kWh)
  - Avg/min/max voltage
  - Average battery percentage
  - Reading count, warning count, OK count
  - Health score percentage
  - Device health status (HEALTHY/DEGRADED/UNHEALTHY)

##### `device_monthly_metrics`
- **Materialization**: Table
- **Granularity**: Monthly per device
- **Purpose**: Monthly aggregated metrics per device
- **Source**: Aggregates from `device_daily_metrics`
- **Metrics**:
  - Total monthly energy consumption (kWh)
  - Avg/min/max voltage
  - Average battery percentage
  - Total readings, warnings, OK count
  - Active days in the month
  - Health score percentage
  - Device health status
- **Additional Fields**: `reading_month`, `year`, `month`

#### Customer-Level Metrics

##### `customer_daily_usage_summary`
- **Materialization**: Table
- **Granularity**: Daily per customer
- **Purpose**: Customer-level daily usage aggregated from all devices
- **Metrics**:
  - Daily total energy consumption across all devices (kWh)
  - Average voltage across all devices
  - Min/max voltage
  - Average battery percentage
  - Active device count
  - Total readings, warnings, OK count
  - Average device health percentage
  - Customer alert status (NORMAL/MONITOR/ACTION_REQUIRED)

##### `customer_monthly_usage_summary`
- **Materialization**: Table
- **Granularity**: Monthly per customer
- **Purpose**: Customer-level monthly usage summary
- **Source**: Aggregates from `device_monthly_metrics`
- **Metrics**:
  - Monthly total energy consumption (kWh)
  - Average voltage across all devices
  - Min/max voltage
  - Average battery percentage
  - Total devices, total readings, warnings, OK count
  - Average device active days
  - Average device health percentage
  - Customer alert status
- **Additional Fields**: `reading_month`, `year`, `month`

##### `customer_usage_mtd_summary`
- **Materialization**: Table
- **Granularity**: Month-to-date (MTD) per customer
- **Purpose**: Current month aggregation with projections
- **Source**: Aggregates from `customer_daily_usage_summary` for current month only
- **Metrics**:
  - MTD total energy consumption (kWh)
  - MTD average/min/max voltage
  - MTD average battery percentage
  - Max active devices
  - MTD total readings, warnings, OK count
  - Days with data
  - Average daily energy (for trending)
  - **Projected monthly energy** (based on daily average)
  - Latest day energy consumption
  - MTD health score percentage
  - MTD alert status
- **Use Case**: Real-time month-to-date reporting and monthly projections

## Execution Modes

### Automatic Mode (Default - Enabled)

dbt automatically runs every 10 minutes in a loop.

**Monitor processing**:
```bash
docker logs -f dbt-transformations
```

**Current setting**: `DBT_AUTO_RUN: "true"` in [docker-compose.yml](docker-compose.yml)

### Manual Mode

**Disable auto-run**: Edit [docker-compose.yml](docker-compose.yml):
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

### Run Specific Model or Layer

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

## Data Lineage

```
Sources:
  kafka.default.telemetry_raw (Kafka topic)

Staging:
  iceberg.staging.stg_telemetry_raw
    ← kafka.default.telemetry_raw

Marts - Device Level:
  iceberg.marts.device_hourly_metrics
    ← iceberg.staging.stg_telemetry_raw

  iceberg.marts.device_daily_metrics
    ← iceberg.staging.stg_telemetry_raw

  iceberg.marts.device_monthly_metrics
    ← iceberg.marts.device_daily_metrics

Marts - Customer Level:
  iceberg.marts.customer_daily_usage_summary
    ← iceberg.marts.device_daily_metrics

  iceberg.marts.customer_monthly_usage_summary
    ← iceberg.marts.device_monthly_metrics

  iceberg.marts.customer_usage_mtd_summary
    ← iceberg.marts.customer_daily_usage_summary (current month only)
```

---

# Apache Superset - Data Visualization

## Overview

Apache Superset provides interactive dashboards and visualizations for the smart energy meter data, connecting directly to Trino for real-time analytics.

## Quick Access

- **URL**: http://localhost:8088
- **Username**: `admin`
- **Password**: `admin123`

Superset is automatically configured during initial setup with a pre-configured Trino connection.

## Key Features

- **Pre-configured Connection**: Trino connection is automatically set up
- **Real-time Dashboards**: Create interactive dashboards from energy data
- **SQL Lab**: Run ad-hoc queries against the data warehouse
- **Multiple Visualizations**: Line charts, bar charts, pie charts, tables, big numbers, and more
- **Scheduled Reports**: Email dashboards on a schedule
- **Row-level Security**: Control data access by user

## Available Data Sources

Once dbt transformations run, you can visualize data at multiple time granularities:

### Device-Level Tables
- **`device_hourly_metrics`**: Hourly device performance and health metrics
- **`device_daily_metrics`**: Daily device performance and health analytics
- **`device_monthly_metrics`**: Monthly device usage and health trends

### Customer-Level Tables
- **`customer_daily_usage_summary`**: Daily customer energy consumption and alerts
- **`customer_monthly_usage_summary`**: Monthly customer usage and health metrics
- **`customer_usage_mtd_summary`**: Month-to-date metrics with monthly projections

### Raw/Staging Tables
- **`stg_telemetry_raw`**: Raw telemetry data from Kafka
- **`stg_meter_health_logs`**: Parsed health and fault logs

## Creating Your First Dashboard

### Step 1: Access Superset
Open http://localhost:8088 and login with `admin` / `admin123`

### Step 2: Explore Data in SQL Lab
1. Navigate to **SQL** → **SQL Lab**
2. Select database: **Trino - Smart Energy Meter**
3. Run exploratory queries:

```sql
-- View customer daily energy usage
SELECT
    customer_id,
    reading_date,
    daily_total_energy_kwh,
    active_devices,
    customer_alert_status
FROM customer_daily_usage_summary
WHERE reading_date >= CURRENT_DATE - INTERVAL '7' DAY
ORDER BY reading_date DESC, customer_id;

-- View month-to-date metrics with projections
SELECT
    customer_id,
    mtd_total_energy_kwh,
    avg_daily_energy_kwh,
    projected_monthly_energy_kwh,
    days_with_data,
    mtd_health_score_pct,
    mtd_alert_status
FROM customer_usage_mtd_summary
ORDER BY mtd_total_energy_kwh DESC;
```

### Step 3: Create Datasets
1. Go to **Data** → **Datasets** → **+ Dataset**
2. Select:
   - Database: **Trino - Smart Energy Meter**
   - Schema: **marts**
   - Table: **customer_daily_usage_summary**
3. Click **Add**

Repeat for other useful tables:
- `customer_usage_mtd_summary` (for month-to-date analytics)
- `customer_monthly_usage_summary` (for monthly trends)
- `device_daily_metrics` (for device-level analysis)
- `device_hourly_metrics` (for intraday patterns)

### Step 4: Build Visualizations

**Example: Daily Energy Consumption Trend**

1. Click on the `customer_daily_usage_summary` dataset
2. **Chart Type**: Line Chart
3. **Metrics**: SUM(`daily_total_energy_kwh`)
4. **X-Axis**: `reading_date`
5. **Group By**: `customer_id`
6. **Filters**: `reading_date` >= 7 days ago
7. Click **Run Query**
8. **Save** your chart

### Step 5: Create Dashboard
1. Go to **Dashboards** → **+ Dashboard**
2. Name it "Energy Monitoring Dashboard"
3. Click **Edit Dashboard**
4. Drag saved charts onto the dashboard
5. Resize and arrange
6. **Save**

## Sample Charts

### 1. Energy Consumption by Customer (Bar Chart)
- **Dataset**: `customer_daily_usage_summary`
- **Chart Type**: Bar Chart
- **X-Axis**: `customer_id`
- **Metric**: SUM(`daily_total_energy_kwh`)
- **Filter**: `reading_date` = today

### 2. Device Health Trend (Line Chart)
- **Dataset**: `device_daily_metrics`
- **Chart Type**: Line Chart
- **X-Axis**: `reading_date`
- **Metric**: AVG(`health_score_pct`)
- **Group By**: `device_id`
- **Filter**: Last 7 days

### 3. Hourly Energy Pattern (Heatmap/Line Chart)
- **Dataset**: `device_hourly_metrics`
- **Chart Type**: Line Chart
- **X-Axis**: `hour_of_day`
- **Metric**: AVG(`total_energy_kwh`)
- **Group By**: `device_id`
- **Filter**: Last 24 hours

### 4. Month-to-Date Energy with Projections (Big Number with Trendline)
- **Dataset**: `customer_usage_mtd_summary`
- **Chart Type**: Big Number with Trendline
- **Metric**: SUM(`mtd_total_energy_kwh`)
- **Comparison Metric**: SUM(`projected_monthly_energy_kwh`)

### 5. Alert Status Distribution (Pie Chart)
- **Dataset**: `customer_daily_usage_summary`
- **Chart Type**: Pie Chart
- **Dimension**: `customer_alert_status`
- **Metric**: COUNT(*)

### 6. Top Energy Consumers (Table)
- **Dataset**: `customer_monthly_usage_summary`
- **Chart Type**: Table
- **Columns**: `customer_id`, `monthly_total_energy_kwh`, `total_devices`, `avg_device_health_pct`
- **Order By**: `monthly_total_energy_kwh` DESC
- **Filter**: Current month
- **Limit**: 10

## Detailed Setup Guide

For comprehensive instructions on creating complex visualizations, alerts, and custom queries, see **[SUPERSET_SETUP.md](SUPERSET_SETUP.md)**.

---

# Project Architecture Overview

## Complete Technology Stack

| Component | Technology | Purpose | Access |
|-----------|-----------|---------|--------|
| **Stream Processing** | Apache Kafka (KRaft) | Real-time telemetry ingestion | localhost:19092 |
| **Kafka Management** | Kafka UI | Topic and message monitoring | http://localhost:8080 |
| **Master Data Store** | PostgreSQL | Customer and device master data | localhost:5432 |
| **Object Storage** | MinIO | Iceberg table storage (S3-compatible) | http://localhost:9000 |
| **Query Engine** | Trino | Distributed SQL across all sources | http://localhost:8081 |
| **Transformations** | dbt | ELT pipelines and data modeling | Container logs |
| **Visualization** | Apache Superset | Dashboards and analytics | http://localhost:8088 |
| **Cache Layer** | Redis | Superset metadata cache | Internal |

## Data Flow

```
IoT Devices (Simulated)
    ↓
[Telemetry Simulator] → [Log Simulator]
    ↓                        ↓
Kafka Topics             Kafka Topics
(telemetry_raw)         (meter_logs)
    ↓                        ↓
    └────────┬───────────────┘
             ↓
        Trino Query Engine
    (Federation Layer)
             ↓
        dbt Transformations
             ↓
    Iceberg Tables (MinIO)
    - Staging:
      • stg_telemetry_raw
      • stg_meter_health_logs
    - Marts (Device Level):
      • device_hourly_metrics
      • device_daily_metrics
      • device_monthly_metrics
    - Marts (Customer Level):
      • customer_daily_usage_summary
      • customer_monthly_usage_summary
      • customer_usage_mtd_summary
             ↓
    ┌────────┴────────┐
    ↓                 ↓
Trino Queries   Apache Superset
                (Dashboards)
```

## Data Types Demonstration

This POC demonstrates handling of all three data types:

1. **Structured**: PostgreSQL master data (customers, devices)
2. **Semi-structured**: JSON telemetry messages in Kafka
3. **Unstructured**: Plain text health logs requiring parsing

---

# Additional Resources

## Documentation Files

- **[QUICKSTART.md](QUICKSTART.md)** - Quick setup and troubleshooting guide
- **[SUPERSET_SETUP.md](SUPERSET_SETUP.md)** - Detailed Superset configuration and chart creation guide
- **[EC2-DEPLOYMENT.md](EC2-DEPLOYMENT.md)** - AWS EC2 deployment instructions

## Simulators

- **[telemetry_simulator.py](telemetry_simulator.py)** - Generates structured JSON telemetry
- **[telemetry_simulator_hist.py](telemetry_simulator_hist.py)** - Historical data generation
- **[log_simulator.py](log_simulator.py)** - Generates unstructured health logs

## Configuration Files

- **[docker-compose.yml](docker-compose.yml)** - Complete infrastructure setup
- **[initial-setup.sh](initial-setup.sh)** - Automated initialization script
- **[dbt-project/](dbt-project/)** - Data transformation models and configuration
- **[trino-config/](trino-config/)** - Trino catalog configurations

---

# Deployment Options

## Local Development (Default)

All services run locally using Docker Compose:
```bash
./initial-setup.sh
```

## AWS EC2 Deployment

For deploying the complete stack to AWS EC2, refer to **[EC2-DEPLOYMENT.md](EC2-DEPLOYMENT.md)** which includes:
- EC2 instance sizing recommendations (minimum t3.medium)
- Security group configuration
- Docker installation steps
- Network configuration for public access
- Production considerations

---

# Monitoring and Management

## Service Health Checks

All services include health checks and automatic restarts:

```bash
# Check all service status
docker-compose ps

# View all logs
docker-compose logs -f

# Check specific service
docker logs -f <container-name>

# Available containers:
# - kafka-kraft
# - postgres-smart-energy-meter
# - minio-storage
# - trino-coordinator
# - dbt-transformations
# - superset
# - redis
```

## Resource Management

Monitor resource usage:

```bash
# Container stats (CPU, memory, network)
docker stats

# System resource usage
docker system df

# View detailed container info
docker inspect <container-name>
```

## Data Management

### Backup PostgreSQL Data
```bash
# Backup master data
docker exec postgres-smart-energy-meter pg_dump -U smartenergymeter smart_energy_meter_db > backup.sql

# Restore backup
docker exec -i postgres-smart-energy-meter psql -U smartenergymeter smart_energy_meter_db < backup.sql
```

### View MinIO Storage
```bash
# View MinIO buckets
docker exec minio-storage mc ls minio/

# View lakehouse data
docker exec minio-storage mc ls minio/lakehouse/

# Check storage usage
docker exec minio-storage mc du minio/lakehouse
```

### Clean Up

```bash
# Stop services (keeps data)
docker-compose down

# Stop and remove all data
docker-compose down -v  # WARNING: Removes all data permanently

# Remove specific volumes
docker volume rm smart-energy-meter_kafka-data
docker volume rm smart-energy-meter_postgres-data
docker volume rm smart-energy-meter_minio-data
```

---

# Troubleshooting

## Common Issues

### Services Not Starting

**Check service status:**
```bash
docker-compose ps
docker logs <container-name>
```

**Restart services:**
```bash
docker-compose restart
```

### Kafka Connection Issues

**Verify Kafka is running:**
```bash
docker exec kafka-kraft kafka-broker-api-versions --bootstrap-server localhost:9092
```

**List topics:**
```bash
docker exec kafka-kraft kafka-topics --list --bootstrap-server localhost:9092
```

### Trino Connection Errors

**Check Trino health:**
```bash
curl http://localhost:8081/v1/info
```

**Wait for initialization:**
Trino takes 2-3 minutes to fully initialize after startup.

### dbt Model Failures

**Test dbt connection:**
```bash
docker exec -it dbt-transformations dbt debug
```

**Create schemas manually:**
```bash
docker exec -it trino-coordinator trino
```

```sql
CREATE SCHEMA IF NOT EXISTS iceberg.staging;
CREATE SCHEMA IF NOT EXISTS iceberg.marts;
```

**Full refresh:**
```bash
docker exec -it dbt-transformations dbt run --full-refresh
```

### No Data in Iceberg Tables

**Check Kafka has messages:**
```bash
docker exec kafka-kraft kafka-console-consumer \
  --topic telemetry_raw \
  --bootstrap-server localhost:9092 \
  --from-beginning \
  --max-messages 5
```

**Verify MinIO storage:**
```bash
docker exec minio-storage mc ls minio/lakehouse/
```

**Check dbt logs:**
```bash
docker logs dbt-transformations
```

### Superset Connection Issues

**Verify Trino is accessible:**
```bash
docker exec superset curl http://trino:8080/v1/info
```

**Restart Superset:**
```bash
docker restart superset
```

**Check Superset logs:**
```bash
docker logs superset
```

---

# Performance Tuning

## Kafka

Edit [docker-compose.yml](docker-compose.yml) for Kafka configuration:
- `KAFKA_NUM_NETWORK_THREADS`: Increase for more concurrent connections
- `KAFKA_NUM_IO_THREADS`: Increase for better I/O throughput
- `KAFKA_LOG_RETENTION_HOURS`: Adjust data retention period

## Trino

Adjust Trino memory and workers:
- Edit `trino-config/config.properties` for coordinator settings
- Increase worker nodes for distributed queries

## dbt

Adjust processing interval:
```yaml
# docker-compose.yml
environment:
  DBT_RUN_INTERVAL: "300"  # Run every 5 minutes instead of 10
```

---

# Support and Contribution

For issues, questions, or contributions:
1. Check the troubleshooting section above
2. Review logs with `docker logs <container-name>`
3. Verify all services are healthy with `docker-compose ps`

---

**License**: This is a Proof of Concept project for demonstration purposes.
