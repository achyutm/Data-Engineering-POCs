# Apache Superset Setup Guide

## Quick Start

Superset is configured and ready to use!

### Access Superset

1. **Open your browser**: http://localhost:8088

2. **Login with**:
   - Username: `admin`
   - Password: `admin123`

---

## Connect to Trino

### Step 1: Add Database Connection

Trino connection is **pre-configured** during initial setup. If you need to add it manually:

1. Click the **+** button → **Data** → **Connect Database**

2. Select **Trino** from the list

3. Fill in the connection details:
   ```
   Display Name:  Trino - Smart Energy Meter
   SQLAlchemy URI: trino://trino:8080/iceberg/marts
   ```

4. Click **Test Connection** → Should show "Connection looks good!"

5. Click **Connect**

### Alternative: Manual SQL Alchemy URI

If Trino option doesn't appear, use **Other**:

```
trino://trino:8080/iceberg/marts
```

---

## Create Your First Chart

### Step 1: Create a Dataset

1. Go to **Data** → **Datasets** → **+ Dataset**

2. Select:
   - Database: **Trino - Smart Energy Meter**
   - Schema: **marts**
   - Table: **customer_daily_usage_summary**

3. Click **Add**

Repeat for other useful tables:
- `customer_usage_mtd_summary` (month-to-date with projections)
- `customer_monthly_usage_summary` (monthly trends)
- `device_daily_metrics` (device-level analysis)
- `device_hourly_metrics` (intraday patterns)
- `device_monthly_metrics` (monthly device trends)

### Step 2: Explore Data

1. Click on the dataset you just created

2. You'll see the Explore interface with:
   - **Metrics** (aggregations)
   - **Dimensions** (grouping)
   - **Filters**
   - **Chart Type**

### Step 3: Create a Chart

**Example: Daily Energy Consumption Trend**

1. **Chart Type**: Line Chart

2. **Metrics**:
   - Click "+ Add metric"
   - Select: `daily_total_energy_kwh`
   - Aggregation: SUM

3. **Dimensions**:
   - X-Axis: `reading_date`
   - Group By: `customer_id`

4. **Filters**:
   - Add filter: `reading_date` >= 7 days ago

5. Click **Run Query**

6. **Save** your chart with a name

---

## Create a Dashboard

### Step 1: Create Dashboard

1. Go to **Dashboards** → **+ Dashboard**

2. Give it a name: "Energy Monitoring Dashboard"

### Step 2: Add Charts

1. Click **Edit Dashboard**

2. Drag and drop your saved charts onto the dashboard

3. Resize and arrange as needed

4. Click **Save**

---

## Sample Charts to Create

### 1. Energy Consumption by Customer (Bar Chart)

- **Dataset**: customer_daily_usage_summary
- **Chart Type**: Bar Chart
- **X-Axis**: customer_id
- **Metric**: SUM(daily_total_energy_kwh)
- **Filter**: reading_date = today

### 2. Device Health Trend (Line Chart)

- **Dataset**: device_daily_metrics
- **Chart Type**: Line Chart
- **X-Axis**: reading_date
- **Metric**: AVG(health_score_pct)
- **Group By**: device_id
- **Filter**: Last 7 days

### 3. Hourly Energy Pattern (Line Chart)

- **Dataset**: device_hourly_metrics
- **Chart Type**: Line Chart
- **X-Axis**: hour_of_day
- **Metric**: AVG(total_energy_kwh)
- **Group By**: device_id
- **Filter**: reading_date = today

### 4. Month-to-Date vs Projected (Big Number)

- **Dataset**: customer_usage_mtd_summary
- **Chart Type**: Big Number with Trendline
- **Metric**: SUM(mtd_total_energy_kwh)
- **Comparison**: SUM(projected_monthly_energy_kwh)
- **Subheader**: MTD vs Projected Monthly

### 5. Alert Status Distribution (Pie Chart)

- **Dataset**: customer_daily_usage_summary
- **Chart Type**: Pie Chart
- **Dimension**: customer_alert_status
- **Metric**: COUNT(*)
- **Filter**: reading_date = today

### 6. Top 10 Monthly Energy Consumers (Table)

- **Dataset**: customer_monthly_usage_summary
- **Chart Type**: Table
- **Columns**: customer_id, monthly_total_energy_kwh, total_devices, avg_device_health_pct
- **Order By**: monthly_total_energy_kwh DESC
- **Filter**: reading_month = current month
- **Limit**: 10

### 7. Device Monthly Comparison (Bar Chart)

- **Dataset**: device_monthly_metrics
- **Chart Type**: Bar Chart
- **X-Axis**: device_id
- **Metric**: SUM(total_energy_kwh)
- **Group By**: year, month
- **Filter**: Last 3 months

---

## Custom SQL Queries

For complex queries, use **SQL Lab**:

1. Go to **SQL** → **SQL Lab**

2. Select database: **Trino - Smart Energy Meter**

3. Write your query:

### Example 1: Daily Energy Usage Trend

```sql
SELECT
    customer_id,
    reading_date,
    daily_total_energy_kwh,
    active_devices,
    avg_device_health_pct,
    customer_alert_status
FROM customer_daily_usage_summary
WHERE reading_date >= CURRENT_DATE - INTERVAL '7' DAY
ORDER BY reading_date DESC, customer_id
LIMIT 100
```

### Example 2: Month-to-Date Performance

```sql
SELECT
    customer_id,
    mtd_total_energy_kwh,
    avg_daily_energy_kwh,
    projected_monthly_energy_kwh,
    days_with_data,
    mtd_health_score_pct,
    mtd_alert_status,
    ROUND((mtd_total_energy_kwh / projected_monthly_energy_kwh) * 100, 2) as pct_of_projected
FROM customer_usage_mtd_summary
WHERE mtd_alert_status != 'NORMAL'
ORDER BY mtd_total_energy_kwh DESC
```

### Example 3: Hourly Peak Analysis

```sql
SELECT
    device_id,
    hour_of_day,
    AVG(total_energy_kwh) as avg_energy,
    MAX(total_energy_kwh) as peak_energy,
    AVG(avg_voltage) as avg_voltage
FROM device_hourly_metrics
WHERE reading_date >= CURRENT_DATE - INTERVAL '7' DAY
GROUP BY device_id, hour_of_day
ORDER BY hour_of_day, device_id
```

### Example 4: Monthly Comparison

```sql
SELECT
    d.device_id,
    d.reading_month,
    d.total_energy_kwh,
    d.active_days,
    d.avg_device_health_pct,
    c.customer_id
FROM device_monthly_metrics d
JOIN postgresql.public.device_master dm ON d.device_id = dm.device_id
JOIN postgresql.public.customer_master c ON dm.customer_id = c.customer_id
WHERE d.reading_month >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '3' MONTH
ORDER BY d.reading_month DESC, d.total_energy_kwh DESC
```

4. Click **Run**

5. You can **Save** this as a dataset for charting

---

## Available Tables

### Analytics Tables (Marts)

#### Device-Level Tables
- **`device_hourly_metrics`** - Hourly device performance and health metrics
  - Fields: device_id, customer_id, reading_hour, hour_of_day, total_energy_kwh, avg/min/max_voltage, avg_battery_pct, health_score_pct, device_health_status
  - Use for: Intraday patterns, peak hour analysis, real-time monitoring

- **`device_daily_metrics`** - Daily device health and performance analytics
  - Fields: device_id, customer_id, reading_date, total_energy_kwh, avg/min/max_voltage, avg_battery_pct, reading_count, warning_count, health_score_pct, device_health_status
  - Use for: Daily trends, device comparisons, health monitoring

- **`device_monthly_metrics`** - Monthly device usage and health trends
  - Fields: device_id, customer_id, reading_month, year, month, total_energy_kwh, active_days, health_score_pct
  - Use for: Long-term trends, monthly comparisons, capacity planning

#### Customer-Level Tables
- **`customer_daily_usage_summary`** - Daily customer energy consumption and alerts
  - Fields: customer_id, reading_date, daily_total_energy_kwh, active_devices, avg_device_health_pct, customer_alert_status
  - Use for: Daily usage tracking, customer comparisons, alert monitoring

- **`customer_monthly_usage_summary`** - Monthly customer usage and health metrics
  - Fields: customer_id, reading_month, year, month, monthly_total_energy_kwh, total_devices, avg_device_active_days, avg_device_health_pct
  - Use for: Monthly billing, trend analysis, customer segmentation

- **`customer_usage_mtd_summary`** - Month-to-date metrics with monthly projections
  - Fields: customer_id, current_month, mtd_total_energy_kwh, avg_daily_energy_kwh, **projected_monthly_energy_kwh**, days_with_data, mtd_health_score_pct, mtd_alert_status
  - Use for: **Real-time monitoring, budget tracking, monthly forecasting**

### Staging Tables
- **`stg_telemetry_raw`** - Raw sensor readings from devices
- **`stg_meter_health_logs`** - Parsed health logs

### Master Data Tables (PostgreSQL)
- **`postgresql.public.customer_master`** - Customer information
- **`postgresql.public.device_master`** - Device information and metadata

---

## Tips & Best Practices

### Performance
- Use filters to limit data range (especially for hourly data)
- Create virtual datasets for frequently used queries
- Enable query caching (Settings → Cache)
- Use appropriate granularity: hourly for real-time, daily for trends, monthly for reports

### Dashboards
- Use native filters for interactive filtering
- Set auto-refresh intervals for real-time monitoring (15-30 minutes for MTD data)
- Combine different time granularities in one dashboard (hourly + daily + MTD)
- Share dashboards with team members

### Recommended Dashboard Layouts

#### Executive Dashboard
- MTD energy consumption vs projection (Big Number)
- Daily energy trend (Line Chart)
- Alert status distribution (Pie Chart)
- Top 10 consumers (Table)

#### Operations Dashboard
- Hourly energy pattern today (Line Chart)
- Device health status (Bar Chart)
- Warning devices list (Table)
- Real-time metrics (Big Numbers)

#### Monthly Report Dashboard
- Monthly consumption by customer (Bar Chart)
- Month-over-month trend (Line Chart)
- Device active days (Table)
- Health score trends (Line Chart)

### Alerts
- Set up email alerts for threshold breaches
- Schedule dashboard emails (daily/weekly/monthly)
- Use SQL Lab for ad-hoc analysis
- Create alerts on MTD projections exceeding budgets

---

## Troubleshooting

### Connection Test Fails

1. Check if Trino is running:
   ```bash
   docker ps | grep trino
   ```

2. Test connection from Superset container:
   ```bash
   docker exec superset curl http://trino:8080/v1/info
   ```

3. Verify the SQLAlchemy URI format:
   ```
   trino://trino:8080/iceberg/marts
   ```

### No Data in Charts

- Verify dbt has run at least once (wait 10 minutes after startup)
- Check if data exists in tables via SQL Lab
- Review date filters in your queries

### Trino Driver Not Found

If you see "trino driver not found":

```bash
docker exec superset pip install trino sqlalchemy-trino
docker restart superset
```

---

## Access Information

- **Superset UI**: http://localhost:8088
- **Username**: admin
- **Password**: admin123
- **Trino Connection**: `trino://trino:8080/iceberg/marts`
- **Trino UI**: http://localhost:8081 (for query monitoring)
- **Kafka UI**: http://localhost:8080 (for topic monitoring)
- **MinIO Console**: http://localhost:9001 (minio / minio123)

---

## Advanced Features

### Custom Visualization
- Install additional visualization plugins
- Create custom chart types

### Alerts & Reporting
- Set up scheduled email reports
- Configure Slack/Teams integrations
- Create threshold alerts

### Access Control
- Create user roles
- Set row-level security
- Configure dashboard permissions

---

That's it! Superset is powerful and intuitive. Start building dashboards!
