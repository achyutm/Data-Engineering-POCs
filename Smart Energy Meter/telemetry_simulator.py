#!/usr/bin/env python3
"""
Smart Energy Meter Telemetry Simulator
Generates and publishes simulated meter telemetry data to Kafka
Reads device and customer mappings from PostgreSQL master data
"""

import json
import random
import time
from datetime import datetime, timezone
from kafka import KafkaProducer
from kafka.errors import KafkaError
import psycopg

# Kafka configuration
KAFKA_BOOTSTRAP_SERVERS = ['localhost:19092']
TOPIC_NAME = 'default.telemetry_raw'

# PostgreSQL configuration
POSTGRES_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'dbname': 'smart_energy_meter_db',
    'user': 'smartenergymeter',
    'password': 'smartenergymeter123'
}

# Simulation parameters
MESSAGE_INTERVAL = 2  # seconds between messages


def load_device_customer_mapping():
    """Load device-customer mappings from PostgreSQL"""
    try:
        conn = psycopg.connect(**POSTGRES_CONFIG)
        cursor = conn.cursor()

        # Query device_master table to get device-customer mappings
        cursor.execute("""
            SELECT device_id, customer_id
            FROM device_master
            WHERE device_status = 'ACTIVE'
            ORDER BY device_id
        """)

        mappings = dict(cursor.fetchall())

        cursor.close()
        conn.close()

        print(f"✓ Loaded {len(mappings)} active devices from PostgreSQL")
        return mappings

    except Exception as e:
        print(f"✗ Failed to load device mappings from PostgreSQL: {e}")
        print("  Make sure PostgreSQL is running and master data is loaded.")
        raise


def create_kafka_producer():
    """Create and configure Kafka producer"""
    try:
        producer = KafkaProducer(
            bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: k.encode('utf-8') if k else None,
            acks='all',  # Wait for all replicas to acknowledge
            retries=3,
            max_in_flight_requests_per_connection=1
        )
        print(f"✓ Connected to Kafka at {KAFKA_BOOTSTRAP_SERVERS}")
        return producer
    except KafkaError as e:
        print(f"✗ Failed to connect to Kafka: {e}")
        raise


def generate_telemetry_message(device_id, customer_id):
    """Generate a single telemetry message"""
    return {
        "device_id": device_id,
        "customer_id": customer_id,
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "metrics": {
            "energy_kwh": round(random.uniform(0.1, 2.5), 2),
            "voltage": round(random.uniform(220.0, 240.0), 1),
            "battery_pct": random.randint(50, 100)
        },
        "status": random.choice(["OK", "OK", "OK", "OK", "WARNING"])  # 80% OK, 20% WARNING
    }


def send_message(producer, message):
    """Send message to Kafka topic"""
    try:
        # Use device_id as the message key for partitioning
        future = producer.send(
            TOPIC_NAME,
            key=message['device_id'],
            value=message
        )

        # Wait for the message to be sent
        record_metadata = future.get(timeout=10)

        print(f"✓ Sent: {message['device_id']} | "
              f"Energy: {message['metrics']['energy_kwh']} kWh | "
              f"Voltage: {message['metrics']['voltage']}V | "
              f"Status: {message['status']} | "
              f"Partition: {record_metadata.partition}")

        return True
    except KafkaError as e:
        print(f"✗ Failed to send message: {e}")
        return False


def main():
    """Main simulation loop"""
    print("=" * 80)
    print("Smart Energy Meter Telemetry Simulator")
    print("=" * 80)
    print(f"Topic: {TOPIC_NAME}")
    print(f"Kafka: {KAFKA_BOOTSTRAP_SERVERS}")
    print(f"Message Interval: {MESSAGE_INTERVAL}s")
    print("=" * 80)
    print()

    # Load device-customer mappings from PostgreSQL
    print("Loading device-customer mappings from PostgreSQL...")
    device_customer_map = load_device_customer_mapping()

    # Get list of devices
    devices = list(device_customer_map.keys())

    # Get unique customers
    unique_customers = set(device_customer_map.values())

    print(f"Devices: {len(devices)} | Customers: {len(unique_customers)}")
    print()

    # Create Kafka producer
    producer = create_kafka_producer()

    print("\nDevice-Customer Mapping:")
    for device, customer in sorted(device_customer_map.items()):
        print(f"  {device} -> {customer}")
    print()
    print("Starting telemetry simulation... (Press Ctrl+C to stop)")
    print("-" * 80)

    message_count = 0

    try:
        while True:
            # Select a random device
            device_id = random.choice(devices)
            customer_id = device_customer_map[device_id]

            # Generate and send telemetry message
            message = generate_telemetry_message(device_id, customer_id)

            if send_message(producer, message):
                message_count += 1

            # Wait before sending next message
            time.sleep(MESSAGE_INTERVAL)

    except KeyboardInterrupt:
        print()
        print("-" * 80)
        print(f"\n✓ Simulation stopped. Total messages sent: {message_count}")
    finally:
        producer.flush()
        producer.close()
        print("✓ Kafka producer closed")


if __name__ == "__main__":
    main()
