insert into "iceberg"."energy_data_staging"."stg_meter_health_logs" ("log_id", "log_timestamp", "log_level", "device_id", "customer_id", "health_event", "health_status", "battery_pct", "voltage_v", "temperature_c", "memory_usage_pct", "uptime_hours", "error_count", "raw_log_message", "processed_at")
    (
        select "log_id", "log_timestamp", "log_level", "device_id", "customer_id", "health_event", "health_status", "battery_pct", "voltage_v", "temperature_c", "memory_usage_pct", "uptime_hours", "error_count", "raw_log_message", "processed_at"
        from "iceberg"."energy_data_staging"."stg_meter_health_logs__dbt_tmp"
    )

