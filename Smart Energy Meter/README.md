# Use Case: Smart Energy Meter – Usage & Health Analytics
This PoC will simulate smart energy meters sending telemetry data and will:

    1. Calculate electricity usage per customer based on meter telemetry.
    2. Monitor and report on the health of energy meters using fault logs and operational metrics.

## Data Types Involved:
    1. Structured: Customer and device master data
    2. Semi-structured: Simulated telemetry data from smart meters (JSON)
    3. Unstructured: Energy meter fault logs (text)

## Proposed Open-Source Technology Stack:
    1. Kafka – Streaming ingestion of real-time telemetry data
    2. PostgreSQL – Storage of customer and device master data
    3. Trino – SQL query layer across data sources and parquet-based analytics storage
    4. dbt – Transformation and modeling (ETL/ELT) layer for curated analytics datasets

The objective of this PoC is to demonstrate a Databricks-equivalent lakehouse-style architecture using only open-source components, aligned to our IoT use cases and future data platform strategy.