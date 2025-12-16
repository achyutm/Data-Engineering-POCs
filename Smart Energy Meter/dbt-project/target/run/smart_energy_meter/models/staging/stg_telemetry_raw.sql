insert into "iceberg"."energy_data_staging"."stg_telemetry_raw" ("telemetry_id", "device_id", "customer_id", "reading_timestamp", "energy_kwh", "voltage", "battery_pct", "status", "ingested_at")
    (
        select "telemetry_id", "device_id", "customer_id", "reading_timestamp", "energy_kwh", "voltage", "battery_pct", "status", "ingested_at"
        from "iceberg"."energy_data_staging"."stg_telemetry_raw__dbt_tmp"
    )

