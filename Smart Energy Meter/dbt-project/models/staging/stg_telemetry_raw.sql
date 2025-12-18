{{
    config(
        materialized='incremental',
        unique_key='telemetry_id'
    )
}}

-- Staging model: Ingest data from Kafka to Iceberg
-- This model reads from kafka.default.telemetry_raw and writes to iceberg.energy_data_staging.stg_telemetry_raw
-- JSON parsing is done at dbt level using CAST(json_parse()) for scalability

WITH parsed_json AS (
    SELECT
        CAST(json_parse(_message) AS ROW(
            device_id VARCHAR,
            customer_id VARCHAR,
            timestamp VARCHAR,
            metrics ROW(energy_kwh DOUBLE, voltage DOUBLE, battery_pct BIGINT),
            status VARCHAR
        )) as msg,
        _timestamp as kafka_timestamp
    FROM {{ source('kafka', 'telemetry_raw') }}
    WHERE _message IS NOT NULL
      AND _message != ''
),

source_data AS (
    SELECT
        msg.device_id as device_id,
        msg.customer_id as customer_id,
        msg.timestamp as timestamp,
        msg.metrics.energy_kwh as metrics_energy_kwh,
        msg.metrics.voltage as metrics_voltage,
        msg.metrics.battery_pct as metrics_battery_pct,
        msg.status as status,
        kafka_timestamp
    FROM parsed_json
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['device_id', 'timestamp']) }} as telemetry_id,
    device_id,
    customer_id,
    CAST(from_iso8601_timestamp(timestamp) AS TIMESTAMP(6)) as reading_timestamp,
    metrics_energy_kwh as energy_kwh,
    metrics_voltage as voltage,
    metrics_battery_pct as battery_pct,
    status,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) as ingested_at
FROM source_data

{% if is_incremental() %}
    WHERE CAST(from_iso8601_timestamp(timestamp) AS TIMESTAMP(6)) > (SELECT COALESCE(MAX(reading_timestamp), TIMESTAMP '2000-01-01 00:00:00') FROM {{ this }})
{% endif %}
