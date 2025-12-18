#!/usr/bin/env python3
"""
Smart Energy Meter - Real-Time Telemetry Simulator
Generates continuous real-time telemetry data
Publishes to Kafka with current timestamps
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

# Real-time simulation parameters
MESSAGE_INTERVAL = 2  # seconds between messages
DUPLICATE_PROBABILITY = 0.05  # 5% chance of sending duplicate messages


def load_device_customer_mapping():
    """Load device-customer mappings from PostgreSQL"""
    try:
        conn = psycopg.connect(**POSTGRES_CONFIG)
        cursor = conn.cursor()

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
        print(f"✗ Failed to load device mappings: {e}")
        raise


def create_kafka_producer():
    """Create Kafka producer"""
    try:
        producer = KafkaProducer(
            bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: k.encode('utf-8') if k else None,
            acks='all',
            retries=3,
            max_in_flight_requests_per_connection=1
        )
        print(f"✓ Connected to Kafka at {KAFKA_BOOTSTRAP_SERVERS}")
        return producer
    except KafkaError as e:
        print(f"✗ Failed to connect to Kafka: {e}")
        raise


def get_hour_multiplier(hour):
    """Get energy consumption multiplier based on hour (realistic usage patterns)"""
    # Peak hours: morning (6-9 AM) and evening (6-10 PM)
    if 6 <= hour < 9 or 18 <= hour < 22:
        return random.uniform(1.8, 2.5)  # Peak usage
    elif 9 <= hour < 18:
        return random.uniform(1.0, 1.5)  # Daytime usage
    else:
        return random.uniform(0.3, 0.7)  # Night/off-peak


def generate_telemetry_message(device_id, customer_id):
    """Generate real-time telemetry message with current timestamp"""
    now = datetime.now(timezone.utc)
    hour_multiplier = get_hour_multiplier(now.hour)
    base_energy = random.uniform(0.3, 1.0)
    energy_kwh = round(base_energy * hour_multiplier, 2)

    return {
        "device_id": device_id,
        "customer_id": customer_id,
        "timestamp": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "metrics": {
            "energy_kwh": energy_kwh,
            "voltage": round(random.uniform(220.0, 240.0), 1),
            "battery_pct": random.randint(60, 100)
        },
        "status": random.choice(["OK"] * 9 + ["WARNING"])  # 90% OK, 10% WARNING
    }


def send_message(producer, message, send_duplicate=False):
    """Send message to Kafka topic with optional duplicate"""
    try:
        # Send original message
        future = producer.send(
            TOPIC_NAME,
            key=message['device_id'],
            value=message
        )

        # Wait for the message to be sent
        record_metadata = future.get(timeout=10)

        duplicate_marker = " [+DUPLICATE]" if send_duplicate else ""
        print(f"✓ {message['timestamp']} | {message['device_id']} | "
              f"Energy: {message['metrics']['energy_kwh']} kWh | "
              f"Voltage: {message['metrics']['voltage']}V | "
              f"Battery: {message['metrics']['battery_pct']}% | "
              f"Status: {message['status']}{duplicate_marker}")

        # Send duplicate if requested
        if send_duplicate:
            producer.send(
                TOPIC_NAME,
                key=message['device_id'],
                value=message
            )

        return True
    except KafkaError as e:
        print(f"✗ Failed to send message: {e}")
        return False


def main():
    """Main simulation loop"""
    print("=" * 80)
    print("Smart Energy Meter - Real-Time Telemetry Simulator")
    print("=" * 80)
    print(f"Topic: {TOPIC_NAME}")
    print(f"Kafka: {KAFKA_BOOTSTRAP_SERVERS}")
    print(f"Message Interval: {MESSAGE_INTERVAL}s")
    print("=" * 80)
    print()

    # Load device-customer mappings
    print("Loading device-customer mappings from PostgreSQL...")
    device_customer_map = load_device_customer_mapping()

    # Get list of devices
    devices = list(device_customer_map.keys())
    unique_customers = set(device_customer_map.values())

    print(f"Devices: {len(devices)} | Customers: {len(unique_customers)}")
    print()

    # Create Kafka producer
    producer = create_kafka_producer()

    print("\nDevice-Customer Mapping:")
    for device, customer in sorted(device_customer_map.items()):
        print(f"  {device} -> {customer}")
    print()
    print(f"Duplicate probability: {DUPLICATE_PROBABILITY * 100}%")
    print("Starting real-time telemetry simulation... (Press Ctrl+C to stop)")
    print("-" * 80)

    message_count = 0
    duplicate_count = 0

    try:
        while True:
            # Select a random device
            device_id = random.choice(devices)
            customer_id = device_customer_map[device_id]

            # Generate and send telemetry message with current timestamp
            message = generate_telemetry_message(device_id, customer_id)

            # Randomly decide to send duplicate (5% chance)
            send_duplicate = random.random() < DUPLICATE_PROBABILITY

            if send_message(producer, message, send_duplicate):
                message_count += 1
                if send_duplicate:
                    duplicate_count += 1
                    message_count += 1

            # Wait before sending next message
            time.sleep(MESSAGE_INTERVAL)

    except KeyboardInterrupt:
        print()
        print("-" * 80)
        print(f"\n✓ Simulation stopped.")
        print(f"  Total messages sent: {message_count}")
        print(f"  Duplicate messages: {duplicate_count}")
    finally:
        producer.flush()
        producer.close()
        print("✓ Kafka producer closed")
        print("=" * 80)


if __name__ == "__main__":
    main()