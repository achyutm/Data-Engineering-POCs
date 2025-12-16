#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "================================================================================"
echo "Smart Energy Meter - Initial Setup"
echo "================================================================================"
echo ""

# Step 1: Clean up existing containers and volumes
echo "Step 1: Cleaning up existing containers and volumes..."
echo "--------------------------------------------------------------------------------"
docker-compose down -v
echo "✓ Cleanup complete"
echo ""

# Step 2: Build and start all services
echo "Step 2: Building and starting all services..."
docker-compose build
echo "  → Starting all services..."
docker-compose up -d
echo "✓ Services started"
echo ""

# Step 3: Wait for PostgreSQL to be ready
echo "Step 3: Waiting for PostgreSQL to be ready..."
echo "--------------------------------------------------------------------------------"
until docker exec postgres-smart-energy-meter pg_isready -U smartenergymeter -d smart_energy_meter_db > /dev/null 2>&1; do
    echo "Waiting for PostgreSQL..."
    sleep 2
done
echo "✓ PostgreSQL is ready"
echo ""

# Step 4: Wait for Trino to be ready
echo "Step 4: Waiting for Trino to be ready..."
echo "--------------------------------------------------------------------------------"
sleep 10
until curl -s -f http://localhost:8081/v1/info > /dev/null 2>&1; do
    echo "Waiting for Trino..."
    sleep 5
done
echo "✓ Trino is ready"
echo ""

# Step 5: Create master data tables and insert data
echo "Step 5: Creating master data tables..."
echo "--------------------------------------------------------------------------------"

echo "  → Creating customer master table..."
docker exec -i postgres-smart-energy-meter psql -U smartenergymeter -d smart_energy_meter_db < master-data/01_create_customer_master.sql
echo "  ✓ Customer master table created"

echo "  → Creating device master table..."
docker exec -i postgres-smart-energy-meter psql -U smartenergymeter -d smart_energy_meter_db < master-data/02_create_device_master.sql
echo "  ✓ Device master table created"

echo "  → Inserting customer data..."
docker exec -i postgres-smart-energy-meter psql -U smartenergymeter -d smart_energy_meter_db < master-data/03_insert_customer_data.sql
echo "  ✓ Customer data inserted"

echo "  → Inserting device data..."
docker exec -i postgres-smart-energy-meter psql -U smartenergymeter -d smart_energy_meter_db < master-data/04_insert_device_data.sql
echo "  ✓ Device data inserted"
echo ""

# Step 6: Verify data
echo "Step 6: Verifying master data..."
echo "--------------------------------------------------------------------------------"
CUSTOMER_COUNT=$(docker exec postgres-smart-energy-meter psql -U smartenergymeter -d smart_energy_meter_db -t -c "SELECT COUNT(*) FROM customer_master;" | xargs)
DEVICE_COUNT=$(docker exec postgres-smart-energy-meter psql -U smartenergymeter -d smart_energy_meter_db -t -c "SELECT COUNT(*) FROM device_master;" | xargs)

echo "  Customer records: $CUSTOMER_COUNT"
echo "  Device records: $DEVICE_COUNT"
echo ""

# Step 7: Initialize Iceberg catalog metadata tables in PostgreSQL
echo "Step 7: Initializing Iceberg catalog metadata..."
echo "--------------------------------------------------------------------------------"
docker exec -i postgres-smart-energy-meter psql -U smartenergymeter -d smart_energy_meter_db <<'EOSQL'
-- Create Iceberg catalog tables if they don't exist
CREATE TABLE IF NOT EXISTS iceberg_namespace_properties (
    catalog_name VARCHAR(255) NOT NULL,
    namespace VARCHAR(255) NOT NULL,
    property_key VARCHAR(255),
    property_value VARCHAR(255),
    PRIMARY KEY (catalog_name, namespace, property_key)
);

CREATE TABLE IF NOT EXISTS iceberg_tables (
    catalog_name VARCHAR(255) NOT NULL,
    table_namespace VARCHAR(255) NOT NULL,
    table_name VARCHAR(255) NOT NULL,
    metadata_location VARCHAR(1000),
    previous_metadata_location VARCHAR(1000),
    PRIMARY KEY (catalog_name, table_namespace, table_name)
);
EOSQL
echo "✓ Iceberg catalog metadata tables created"
echo ""

# Step 8: Create Iceberg schemas in Trino
echo "Step 8: Creating Iceberg schemas..."
echo "--------------------------------------------------------------------------------"
docker exec trino-coordinator trino --execute "CREATE SCHEMA IF NOT EXISTS iceberg.energy_data_staging WITH (location = 's3://lakehouse/energy_data_staging/')" 2>/dev/null || echo "  ⚠️  Schema energy_data_staging may already exist"
docker exec trino-coordinator trino --execute "CREATE SCHEMA IF NOT EXISTS iceberg.energy_data_marts WITH (location = 's3://lakehouse/energy_data_marts/')" 2>/dev/null || echo "  ⚠️  Schema energy_data_marts may already exist"
echo "✓ Iceberg schemas created"
echo ""

# Step 9: Verify dbt dependencies
echo "Step 9: Verifying dbt dependencies..."
echo "--------------------------------------------------------------------------------"
if docker exec dbt-transformations ls /dbt/dbt_packages/dbt_utils > /dev/null 2>&1; then
    echo "✓ dbt_utils package installed (via Dockerfile)"
else
    echo "⚠️  dbt_utils not found, will be installed on container start"
fi
echo ""

# Step 10: Install Python dependencies
echo "Step 10: Installing Python dependencies..."
echo "--------------------------------------------------------------------------------"

# Install required packages
pip install -r requirements.txt > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Python dependencies installed"
else
    echo "⚠️  Failed to install Python dependencies"
    echo "   Please run manually: pip install -r requirements.txt"
fi
echo ""

# Final Step: Display service status
echo "================================================================================"
echo "Setup Complete!"
echo "================================================================================"
echo ""
echo "Services Running:"
echo "  - Kafka:           http://localhost:19092 (bootstrap server)"
echo "  - Kafka UI:        http://localhost:8080"
echo "  - PostgreSQL:      localhost:5432"
echo "  - MinIO Console:   http://localhost:9001 (minio/minio123)"
echo "  - MinIO S3 API:    http://localhost:9000"
echo "  - Trino:           http://localhost:8081"
echo "  - dbt:             Running in container"
echo ""
echo "Master Data:"
echo "  - Customers:       $CUSTOMER_COUNT records"
echo "  - Devices:         $DEVICE_COUNT records"
echo ""
echo "Next Steps:"
echo "  1. Start telemetry simulator:  python3 telemetry_simulator.py"
echo "  2. dbt will automatically process data every 10 minutes"
echo "  3. Manual dbt run (optional): docker exec -it dbt-transformations dbt run"
echo "  4. Monitor dbt logs:          docker logs -f dbt-transformations"
echo ""
echo "Query Data:"
echo "  docker exec -it trino-coordinator trino"
echo "  SELECT * FROM postgresql.public.customer_master;"
echo "  SELECT * FROM kafka.default.telemetry_raw LIMIT 10;"
echo "  SELECT * FROM iceberg.staging.stg_telemetry_raw LIMIT 10;"
echo "  SELECT * FROM iceberg.marts.device_daily_metrics;"
echo ""
