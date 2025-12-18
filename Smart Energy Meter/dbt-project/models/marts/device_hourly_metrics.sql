{{
    config(
        materialized='table'
    )
}}

-- Analytics model: Hourly aggregated metrics per device
-- Calculates total energy consumption, average voltage, and device health per hour
-- Deduplicates messages based on device_id + reading_timestamp

WITH deduplicated_readings AS (
    SELECT
        device_id,
        customer_id,
        reading_timestamp,
        energy_kwh,
        voltage,
        battery_pct,
        status,
        ROW_NUMBER() OVER (
            PARTITION BY device_id, reading_timestamp
            ORDER BY ingested_at DESC
        ) as row_num
    FROM {{ ref('stg_telemetry_raw') }}
),

cleaned_readings AS (
    SELECT
        device_id,
        customer_id,
        reading_timestamp,
        energy_kwh,
        voltage,
        battery_pct,
        status
    FROM deduplicated_readings
    WHERE row_num = 1  -- Keep only the latest ingested record for duplicates
),

hourly_readings AS (
    SELECT
        device_id,
        customer_id,
        DATE_TRUNC('hour', reading_timestamp) as reading_hour,
        SUM(energy_kwh) as total_energy_kwh,
        AVG(voltage) as avg_voltage,
        MIN(voltage) as min_voltage,
        MAX(voltage) as max_voltage,
        AVG(battery_pct) as avg_battery_pct,
        COUNT(*) as reading_count,
        SUM(CASE WHEN status = 'WARNING' THEN 1 ELSE 0 END) as warning_count,
        SUM(CASE WHEN status = 'OK' THEN 1 ELSE 0 END) as ok_count
    FROM cleaned_readings
    GROUP BY
        device_id,
        customer_id,
        DATE_TRUNC('hour', reading_timestamp)
)

SELECT
    device_id,
    customer_id,
    reading_hour,
    DATE(reading_hour) as reading_date,
    HOUR(reading_hour) as hour_of_day,
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
FROM hourly_readings
ORDER BY reading_hour DESC, device_id