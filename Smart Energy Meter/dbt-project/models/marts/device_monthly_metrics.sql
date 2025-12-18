{{
    config(
        materialized='table'
    )
}}

-- Analytics model: Monthly aggregated metrics per device
-- Aggregates daily metrics to monthly level

WITH monthly_readings AS (
    SELECT
        device_id,
        customer_id,
        DATE_TRUNC('month', reading_date) as reading_month,
        SUM(total_energy_kwh) as total_energy_kwh,
        AVG(avg_voltage) as avg_voltage,
        MIN(min_voltage) as min_voltage,
        MAX(max_voltage) as max_voltage,
        AVG(avg_battery_pct) as avg_battery_pct,
        SUM(reading_count) as reading_count,
        SUM(warning_count) as warning_count,
        SUM(ok_count) as ok_count,
        COUNT(DISTINCT reading_date) as active_days
    FROM {{ ref('device_daily_metrics') }}
    GROUP BY
        device_id,
        customer_id,
        DATE_TRUNC('month', reading_date)
)

SELECT
    device_id,
    customer_id,
    reading_month,
    YEAR(reading_month) as year,
    MONTH(reading_month) as month,
    total_energy_kwh,
    avg_voltage,
    min_voltage,
    max_voltage,
    avg_battery_pct,
    reading_count,
    warning_count,
    ok_count,
    active_days,
    ROUND(CAST(ok_count AS DOUBLE) / NULLIF(reading_count, 0) * 100, 2) as health_score_pct,
    CASE
        WHEN warning_count > reading_count * 0.1 THEN 'UNHEALTHY'
        WHEN warning_count > 0 THEN 'DEGRADED'
        ELSE 'HEALTHY'
    END as device_health_status
FROM monthly_readings
ORDER BY reading_month DESC, device_id