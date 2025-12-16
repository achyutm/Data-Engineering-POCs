{{
    config(
        materialized='incremental',
        unique_key='log_id'
    )
}}

-- Staging model: Parse UNSTRUCTURED health logs from Kafka
-- This model reads plain text logs and extracts structured data using regex and string functions
-- Input: kafka.default.meter_logs (plain text, multiple formats)
-- Output: iceberg.energy_data_staging.stg_meter_health_logs (structured)

WITH raw_logs AS (
    SELECT
        _message as raw_log_message,
        _timestamp as kafka_timestamp,
        _key as device_id_key
    FROM {{ source('kafka', 'meter_logs') }}
    WHERE _message IS NOT NULL
      AND _message != ''
),

parsed_logs AS (
    SELECT
        raw_log_message,
        kafka_timestamp,
        device_id_key,

        -- Extract timestamp (first datetime pattern in log)
        regexp_extract(raw_log_message, '(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})', 1) as log_timestamp_str,

        -- Extract log level (INFO, WARN, ERROR, CRITICAL)
        regexp_extract(raw_log_message, '\[(INFO|WARN|ERROR|CRITICAL)\]', 1) as log_level,

        -- Extract device_id (MTR-\d+ pattern)
        regexp_extract(raw_log_message, '(MTR-\d+)', 1) as device_id,

        -- Extract customer_id (CUST-\d+ pattern)
        regexp_extract(raw_log_message, '(CUST-\d+)', 1) as customer_id,

        -- Extract health event (all caps with underscores)
        regexp_extract(raw_log_message, '(HEALTH_CHECK_OK|HEALTH_CHECK_DEGRADED|BATTERY_LOW|VOLTAGE_ANOMALY|CONNECTIVITY_ISSUE|SENSOR_FAULT|CALIBRATION_DRIFT|MEMORY_WARNING|TEMPERATURE_HIGH|FIRMWARE_UPDATE_REQUIRED)', 1) as health_event,

        -- Extract health status
        regexp_extract(raw_log_message, 'status=(\w+)', 1) as health_status_raw,
        regexp_extract(raw_log_message, 'Status: (\w+)', 1) as health_status_alt,
        regexp_extract(raw_log_message, 'status is (\w+)', 1) as health_status_nl,

        -- Extract battery percentage
        CAST(regexp_extract(raw_log_message, 'battery=(\d+)', 1) AS INTEGER) as battery_pct,

        -- Extract voltage
        CAST(regexp_extract(raw_log_message, 'voltage=([0-9.]+)', 1) AS DOUBLE) as voltage_v,

        -- Extract temperature
        CAST(regexp_extract(raw_log_message, 'temp=([0-9.]+)', 1) AS DOUBLE) as temperature_c,

        -- Extract memory usage
        CAST(regexp_extract(raw_log_message, 'memory=(\d+)', 1) AS INTEGER) as memory_usage_pct,
        CAST(regexp_extract(raw_log_message, 'mem=(\d+)', 1) AS INTEGER) as memory_usage_alt,

        -- Extract uptime
        CAST(regexp_extract(raw_log_message, 'uptime=(\d+)', 1) AS INTEGER) as uptime_hours,
        CAST(regexp_extract(raw_log_message, 'up=(\d+)', 1) AS INTEGER) as uptime_hours_alt,

        -- Extract error count
        CAST(regexp_extract(raw_log_message, 'errors=(\d+)', 1) AS INTEGER) as error_count,
        CAST(regexp_extract(raw_log_message, 'err_cnt=(\d+)', 1) AS INTEGER) as error_count_alt

    FROM raw_logs
),

cleaned_logs AS (
    SELECT
        raw_log_message,
        kafka_timestamp,

        -- Parse timestamp
        CASE
            WHEN log_timestamp_str IS NOT NULL AND log_timestamp_str != ''
            THEN CAST(from_iso8601_timestamp(REPLACE(log_timestamp_str, ' ', 'T') || 'Z') AS TIMESTAMP(6))
            ELSE CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6))
        END as log_timestamp,

        log_level,
        device_id,
        customer_id,
        health_event,

        -- Consolidate health_status from multiple extraction patterns
        COALESCE(health_status_raw, health_status_alt, health_status_nl, 'UNKNOWN') as health_status,

        battery_pct,
        voltage_v,
        temperature_c,

        -- Consolidate memory and uptime from multiple patterns
        COALESCE(memory_usage_pct, memory_usage_alt) as memory_usage_pct,
        COALESCE(uptime_hours, uptime_hours_alt) as uptime_hours,
        COALESCE(error_count, error_count_alt, 0) as error_count

    FROM parsed_logs
    WHERE device_id IS NOT NULL  -- Only keep logs with identifiable device
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['device_id', 'log_timestamp', 'raw_log_message']) }} as log_id,
    log_timestamp,
    log_level,
    device_id,
    customer_id,
    health_event,
    health_status,
    battery_pct,
    voltage_v,
    temperature_c,
    memory_usage_pct,
    uptime_hours,
    error_count,
    raw_log_message,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) as processed_at
FROM cleaned_logs

{% if is_incremental() %}
    WHERE log_timestamp > (SELECT COALESCE(MAX(log_timestamp), TIMESTAMP '2000-01-01 00:00:00') FROM {{ this }})
{% endif %}
