
  
    

    create table "iceberg"."energy_data_marts"."customer_usage_summary__dbt_tmp"
      
      
    as (
      

-- Analytics model: Customer usage summary
-- Aggregates energy consumption and device health metrics per customer

WITH customer_metrics AS (
    SELECT
        customer_id,
        reading_date,
        SUM(total_energy_kwh) as daily_total_energy_kwh,
        AVG(avg_voltage) as avg_voltage,
        COUNT(DISTINCT device_id) as active_devices,
        SUM(warning_count) as total_warnings,
        SUM(reading_count) as total_readings,
        AVG(health_score_pct) as avg_device_health_pct
    FROM "iceberg"."energy_data_marts"."device_daily_metrics"
    GROUP BY
        customer_id,
        reading_date
)

SELECT
    customer_id,
    reading_date,
    daily_total_energy_kwh,
    avg_voltage,
    active_devices,
    total_warnings,
    total_readings,
    ROUND(avg_device_health_pct, 2) as avg_device_health_pct,
    CASE
        WHEN total_warnings > total_readings * 0.05 THEN 'ACTION_REQUIRED'
        WHEN total_warnings > 0 THEN 'MONITOR'
        ELSE 'NORMAL'
    END as customer_alert_status
FROM customer_metrics
ORDER BY reading_date DESC, customer_id
    );

  