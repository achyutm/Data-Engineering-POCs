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

1. Click the **+** button → **Data** → **Connect Database**

2. Select **Trino** from the list

3. Fill in the connection details:
   ```
   Display Name:  Trino - Smart Energy Meter
   SQLAlchemy URI: trino://trino:8080/iceberg/energy_data_marts
   ```

4. Click **Test Connection** → Should show "Connection looks good!"

5. Click **Connect**

### Alternative: Manual SQL Alchemy URI

If Trino option doesn't appear, use **Other**:

```
trino://trino:8080/iceberg/energy_data_marts
```

---

## Create Your First Chart

### Step 1: Create a Dataset

1. Go to **Data** → **Datasets** → **+ Dataset**

2. Select:
   - Database: **Trino - Smart Energy Meter**
   - Schema: **energy_data_marts**
   - Table: **customer_usage_summary**

3. Click **Add**

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

- **Dataset**: customer_usage_summary
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

### 3. Alert Status Distribution (Pie Chart)

- **Dataset**: customer_usage_summary
- **Chart Type**: Pie Chart
- **Dimension**: customer_alert_status
- **Metric**: COUNT(*)

### 4. Top 10 Energy Consumers (Big Number)

- **Dataset**: customer_usage_summary
- **Chart Type**: Table
- **Columns**: customer_id, daily_total_energy_kwh
- **Order By**: daily_total_energy_kwh DESC
- **Limit**: 10

---

## Custom SQL Queries

For complex queries, use **SQL Lab**:

1. Go to **SQL** → **SQL Lab**

2. Select database: **Trino - Smart Energy Meter**

3. Write your query:

```sql
SELECT
    customer_id,
    reading_date,
    daily_total_energy_kwh,
    active_devices,
    avg_device_health_pct,
    customer_alert_status
FROM customer_usage_summary
WHERE reading_date >= CURRENT_DATE - INTERVAL '7' DAY
ORDER BY reading_date DESC, customer_id
LIMIT 100
```

4. Click **Run**

5. You can **Save** this as a dataset for charting

---

## Available Tables

### Analytics Tables (Marts)
- `customer_usage_summary` - Daily customer energy usage and alerts
- `device_daily_metrics` - Daily device health and performance metrics

### Staging Tables
- `stg_telemetry_raw` - Raw sensor readings from devices
- `stg_meter_health_logs` - Parsed health logs

---

## Tips & Best Practices

### Performance
- Use filters to limit data range
- Create virtual datasets for frequently used queries
- Enable query caching (Settings → Cache)

### Dashboards
- Use native filters for interactive filtering
- Set auto-refresh intervals for real-time monitoring
- Share dashboards with team members

### Alerts
- Set up email alerts for threshold breaches
- Schedule dashboard emails
- Use SQL Lab for ad-hoc analysis

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
   trino://trino:8080/iceberg/energy_data_marts
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
- **Trino Connection**: `trino://trino:8080/iceberg/energy_data_marts`
- **dbt Docs**: http://localhost:8082 (for data lineage)
- **Trino UI**: http://localhost:8081 (for query monitoring)

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
