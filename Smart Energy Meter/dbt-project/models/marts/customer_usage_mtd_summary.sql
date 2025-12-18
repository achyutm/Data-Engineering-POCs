{{
    config(
        materialized='table'
    )
}}

-- Analytics model: Customer usage summary for current month (MTD - Month to Date)
-- Shows aggregated usage for the ongoing month only

WITH current_month_data AS (
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
        avg_device_health_pct
    FROM {{ ref('customer_daily_usage_summary') }}
    WHERE DATE_TRUNC('month', reading_date) = DATE_TRUNC('month', CURRENT_DATE)
),

customer_mtd_summary AS (
    SELECT
        customer_id,

        -- MTD aggregations
        SUM(daily_total_energy_kwh) as mtd_total_energy_kwh,
        AVG(avg_voltage) as mtd_avg_voltage,
        MIN(min_voltage) as mtd_min_voltage,
        MAX(max_voltage) as mtd_max_voltage,
        AVG(avg_battery_pct) as mtd_avg_battery_pct,
        MAX(active_devices) as max_active_devices,
        SUM(total_readings) as mtd_total_readings,
        SUM(total_warnings) as mtd_total_warnings,
        SUM(total_ok) as mtd_total_ok,

        -- Trend metrics
        COUNT(DISTINCT reading_date) as days_with_data,
        AVG(daily_total_energy_kwh) as avg_daily_energy_kwh,
        MIN(reading_date) as first_reading_date,
        MAX(reading_date) as last_reading_date,

        -- Latest day metrics for comparison
        MAX(CASE WHEN reading_date = (SELECT MAX(reading_date) FROM current_month_data)
            THEN daily_total_energy_kwh END) as latest_day_energy_kwh

    FROM current_month_data
    GROUP BY customer_id
)

SELECT
    customer_id,
    DATE_TRUNC('month', CURRENT_DATE) as current_month,
    YEAR(CURRENT_DATE) as year,
    MONTH(CURRENT_DATE) as month,

    -- MTD totals
    mtd_total_energy_kwh,
    ROUND(mtd_avg_voltage, 2) as mtd_avg_voltage,
    mtd_min_voltage,
    mtd_max_voltage,
    ROUND(mtd_avg_battery_pct, 1) as mtd_avg_battery_pct,
    max_active_devices,
    mtd_total_readings,
    mtd_total_warnings,
    mtd_total_ok,

    -- Trend and projection
    days_with_data,
    ROUND(avg_daily_energy_kwh, 2) as avg_daily_energy_kwh,
    ROUND(avg_daily_energy_kwh * DAY(LAST_DAY_OF_MONTH(CURRENT_DATE)), 2) as projected_monthly_energy_kwh,
    first_reading_date,
    last_reading_date,
    latest_day_energy_kwh,

    -- Health metrics
    ROUND(CAST(mtd_total_ok AS DOUBLE) / NULLIF(mtd_total_readings, 0) * 100, 2) as mtd_health_score_pct,

    -- Alert status
    CASE
        WHEN mtd_total_warnings > mtd_total_readings * 0.05 THEN 'ACTION_REQUIRED'
        WHEN mtd_total_warnings > 0 THEN 'MONITOR'
        ELSE 'NORMAL'
    END as mtd_alert_status

FROM customer_mtd_summary
ORDER BY customer_id
