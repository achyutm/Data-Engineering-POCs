{{
    config(
        materialized='table'
    )
}}

-- Analytics model: Customer daily usage summary
-- Aggregates device daily metrics per customer per day

WITH customer_daily_metrics AS (
    SELECT
        customer_id,
        reading_date,
        SUM(total_energy_kwh) as daily_total_energy_kwh,
        AVG(avg_voltage) as avg_voltage,
        MIN(min_voltage) as min_voltage,
        MAX(max_voltage) as max_voltage,
        AVG(avg_battery_pct) as avg_battery_pct,
        COUNT(DISTINCT device_id) as active_devices,
        SUM(reading_count) as total_readings,
        SUM(warning_count) as total_warnings,
        SUM(ok_count) as total_ok,
        AVG(health_score_pct) as avg_device_health_pct
    FROM {{ ref('device_daily_metrics') }}
    GROUP BY
        customer_id,
        reading_date
)

SELECT
    customer_id,
    reading_date,
    daily_total_energy_kwh,
    avg_voltage,
    min_voltage,
    max_voltage,
    avg_battery_pct,
    active_devices,
    total_readings,
    total_warnings,
    total_ok,
    ROUND(avg_device_health_pct, 2) as avg_device_health_pct,
    CASE
        WHEN total_warnings > total_readings * 0.05 THEN 'ACTION_REQUIRED'
        WHEN total_warnings > 0 THEN 'MONITOR'
        ELSE 'NORMAL'
    END as customer_alert_status
FROM customer_daily_metrics
ORDER BY reading_date DESC, customer_id