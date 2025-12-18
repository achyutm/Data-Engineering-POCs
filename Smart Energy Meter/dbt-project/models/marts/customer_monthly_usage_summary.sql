{{
    config(
        materialized='table'
    )
}}

-- Analytics model: Customer monthly usage summary
-- Aggregates device monthly metrics per customer

WITH customer_monthly_metrics AS (
    SELECT
        customer_id,
        reading_month,
        SUM(total_energy_kwh) as monthly_total_energy_kwh,
        AVG(avg_voltage) as avg_voltage,
        MIN(min_voltage) as min_voltage,
        MAX(max_voltage) as max_voltage,
        AVG(avg_battery_pct) as avg_battery_pct,
        COUNT(DISTINCT device_id) as total_devices,
        SUM(reading_count) as total_readings,
        SUM(warning_count) as total_warnings,
        SUM(ok_count) as total_ok,
        AVG(health_score_pct) as avg_device_health_pct,
        AVG(active_days) as avg_device_active_days
    FROM {{ ref('device_monthly_metrics') }}
    GROUP BY
        customer_id,
        reading_month
)

SELECT
    customer_id,
    reading_month,
    YEAR(reading_month) as year,
    MONTH(reading_month) as month,
    monthly_total_energy_kwh,
    avg_voltage,
    min_voltage,
    max_voltage,
    avg_battery_pct,
    total_devices,
    total_readings,
    total_warnings,
    total_ok,
    ROUND(avg_device_active_days, 1) as avg_device_active_days,
    ROUND(avg_device_health_pct, 2) as avg_device_health_pct,
    CASE
        WHEN total_warnings > total_readings * 0.05 THEN 'ACTION_REQUIRED'
        WHEN total_warnings > 0 THEN 'MONITOR'
        ELSE 'NORMAL'
    END as customer_alert_status
FROM customer_monthly_metrics
ORDER BY reading_month DESC, customer_id