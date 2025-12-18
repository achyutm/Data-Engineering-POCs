#!/usr/bin/env python3
"""
Smart Energy Meter - Historical Data Generator
Generates 1 message per device per hour for the last 3 months
Publishes all historical data to Kafka in one run
"""

import json
import random
from datetime import datetime, timezone, timedelta
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

# Historical data generation parameters
MONTHS_BACK = 3  # Generate data for last 3 months
READING_INTERVAL_HOURS = 1  # One reading per device per hour
BATCH_SIZE = 100  # Kafka batch size for progress reporting
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
    """Create Kafka producer with optimized settings for bulk load"""
    try:
        producer = KafkaProducer(
            bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: k.encode('utf-8') if k else None,
            acks='all',
            retries=3,
            compression_type='gzip',
            batch_size=32768,  # Larger batch size for bulk load
            linger_ms=100       # Wait up to 100ms to batch messages
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


def get_day_multiplier(day_of_week):
    """Get energy consumption multiplier based on day of week"""
    # 0 = Monday, 6 = Sunday
    if day_of_week >= 5:  # Weekend (Saturday, Sunday)
        return random.uniform(1.2, 1.4)  # Higher weekend usage
    else:
        return random.uniform(0.9, 1.1)  # Normal weekday


def generate_telemetry_message(device_id, customer_id, timestamp):
    """Generate telemetry message for a specific timestamp"""
    hour_multiplier = get_hour_multiplier(timestamp.hour)
    day_multiplier = get_day_multiplier(timestamp.weekday())
    base_energy = random.uniform(0.3, 1.0)
    energy_kwh = round(base_energy * hour_multiplier * day_multiplier, 2)

    return {
        "device_id": device_id,
        "customer_id": customer_id,
        "timestamp": timestamp.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "metrics": {
            "energy_kwh": energy_kwh,
            "voltage": round(random.uniform(220.0, 240.0), 1),
            "battery_pct": random.randint(60, 100)
        },
        "status": random.choice(["OK"] * 9 + ["WARNING"])  # 90% OK, 10% WARNING
    }


def generate_historical_data(device_customer_map, start_date, end_date):
    """
    Generate historical telemetry messages
    Strategy: 1 message per device per hour
    """
    messages = []
    devices = list(device_customer_map.keys())
    num_devices = len(devices)

    print(f"\nHistorical Data Generation Configuration:")
    print(f"  Start Date: {start_date.date()}")
    print(f"  End Date: {end_date.date()}")
    print(f"  Duration: {(end_date - start_date).days} days (~{MONTHS_BACK} months)")
    print(f"  Devices: {num_devices}")
    print(f"  Reading Interval: {READING_INTERVAL_HOURS} hour per device")
    print(f"  Messages per device per day: {24 / READING_INTERVAL_HOURS}")
    print()

    # Calculate expected total messages
    total_hours = (end_date - start_date).total_seconds() / 3600
    expected_per_device = int(total_hours / READING_INTERVAL_HOURS)
    expected_total = expected_per_device * num_devices
    print(f"Expected readings per device: {expected_per_device:,}")
    print(f"Expected total messages: {expected_total:,}")
    print()

    # Generate messages for each device
    for device_id, customer_id in device_customer_map.items():
        current_time = start_date
        device_messages = 0

        while current_time < end_date:
            message = generate_telemetry_message(device_id, customer_id, current_time)
            messages.append(message)
            device_messages += 1
            current_time += timedelta(hours=READING_INTERVAL_HOURS)

        print(f"  {device_id} ({customer_id}): {device_messages:,} readings generated")

    print(f"\n✓ Total messages generated: {len(messages):,}")
    return messages


def publish_messages(producer, messages, batch_size=500):
    """Publish messages to Kafka in batches with progress reporting and random duplicates"""
    total = len(messages)
    sent = 0
    failed = 0
    duplicates = 0

    print(f"\n{'=' * 80}")
    print(f"Publishing {total:,} messages to Kafka...")
    print(f"Duplicate probability: {DUPLICATE_PROBABILITY * 100}%")
    print(f"{'=' * 80}")

    for i, message in enumerate(messages):
        try:
            # Send original message
            producer.send(
                TOPIC_NAME,
                key=message['device_id'],
                value=message
            )
            sent += 1

            # Randomly send duplicate (5% chance)
            if random.random() < DUPLICATE_PROBABILITY:
                producer.send(
                    TOPIC_NAME,
                    key=message['device_id'],
                    value=message
                )
                duplicates += 1
                sent += 1

            # Print progress every batch_size messages
            if (i + 1) % batch_size == 0:
                progress = ((i + 1) / total) * 100
                print(f"Progress: {i + 1:,}/{total:,} ({progress:.1f}%) | "
                      f"Timestamp: {message['timestamp']} | "
                      f"Device: {message['device_id']} | "
                      f"Duplicates: {duplicates:,}")
                producer.flush()  # Flush batch to Kafka

        except KafkaError as e:
            failed += 1
            if failed <= 10:  # Only print first 10 errors
                print(f"✗ Failed to send message: {e}")

    # Final flush
    producer.flush()

    print(f"{'=' * 80}")
    print(f"\n✓ Publishing complete!")
    print(f"  Successfully sent: {sent:,} messages")
    print(f"  Original messages: {total:,}")
    print(f"  Duplicate messages: {duplicates:,}")
    print(f"  Failed: {failed:,} messages")
    print(f"  Success rate: {(sent/(total + duplicates))*100:.2f}%")

    return sent, failed


def main():
    """Main function"""
    print("=" * 80)
    print("Smart Energy Meter - Historical Data Generator")
    print("=" * 80)
    print()

    # Load device mappings
    device_customer_map = load_device_customer_mapping()

    # Calculate start and end dates
    end_date = datetime.now(timezone.utc)
    start_date = end_date - timedelta(days=MONTHS_BACK * 30)  # Approximate months as 30 days

    # Generate historical messages
    messages = generate_historical_data(
        device_customer_map,
        start_date,
        end_date
    )

    # Create Kafka producer
    producer = create_kafka_producer()

    # Publish messages
    sent, failed = publish_messages(producer, messages, BATCH_SIZE)

    # Cleanup
    producer.close()
    print("\n✓ Kafka producer closed")
    print("=" * 80)
    print("\nNext steps:")
    print("  1. Run dbt to process the data: docker exec dbt-transformations dbt run")
    print("  2. View dashboards in Superset: http://localhost:8088")
    print("=" * 80)


if __name__ == "__main__":
    main()
