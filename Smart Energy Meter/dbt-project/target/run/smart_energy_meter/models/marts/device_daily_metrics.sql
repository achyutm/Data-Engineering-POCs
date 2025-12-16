
  
    

    create table "iceberg"."energy_data_marts"."device_daily_metrics__dbt_tmp"
      
      
    as (
      

-- Analytics model: Daily aggregated metrics per device
-- Calculates total energy consumption, average voltage, and device health per day

WITH daily_readings AS (
    SELECT
        device_id,
        customer_id,
        DATE(reading_timestamp) as reading_date,
        SUM(energy_kwh) as total_energy_kwh,
        AVG(voltage) as avg_voltage,
        MIN(voltage) as min_voltage,
        MAX(voltage) as max_voltage,
        AVG(battery_pct) as avg_battery_pct,
        COUNT(*) as reading_count,
        SUM(CASE WHEN status = 'WARNING' THEN 1 ELSE 0 END) as warning_count,
        SUM(CASE WHEN status = 'OK' THEN 1 ELSE 0 END) as ok_count
    FROM "iceberg"."energy_data_staging"."stg_telemetry_raw"
    GROUP BY
        device_id,
        customer_id,
        DATE(reading_timestamp)
)

SELECT
    device_id,
    customer_id,
    reading_date,
    total_energy_kwh,
    avg_voltage,
    min_voltage,
    max_voltage,
    avg_battery_pct,
    reading_count,
    warning_count,
    ok_count,
    ROUND(CAST(ok_count AS DOUBLE) / NULLIF(reading_count, 0) * 100, 2) as health_score_pct,
    CASE
        WHEN warning_count > reading_count * 0.1 THEN 'UNHEALTHY'
        WHEN warning_count > 0 THEN 'DEGRADED'
        ELSE 'HEALTHY'
    END as device_health_status
FROM daily_readings
ORDER BY reading_date DESC, device_id
    );

  