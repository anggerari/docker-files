"""Connects to every docker-files service that is running and does one real
operation on each. Services that aren't running are skipped.

    pip install -r requirements.txt && python main.py
    (settings come from env vars - see `make urls`)
"""
import os
import smtplib
import sys
import time
import uuid
from email.message import EmailMessage


def env(key, default):
    return os.environ.get(key) or default


failed = False


def run(name, fn):
    global failed
    try:
        print(f"  ✓ {name:<9} {fn()}")
    except Exception as err:  # noqa: BLE001 - example code: report and continue
        text = f"{type(err).__name__} {err}"
        if any(s in text for s in ("Connection refused", "ConnectionRefused", "ECONNREFUSED", "AMQPConnectionError",
                                    "Connect call failed", "Failed to resolve", "_TRANSPORT", "EndpointConnectionError")):
            print(f"  - {name:<9} not running, skipped")
        else:
            failed = True
            print(f"  ✗ {name:<9} {text}")


def postgres():
    import psycopg

    with psycopg.connect(env("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/app"), connect_timeout=5) as conn:
        conn.execute("CREATE TEMP TABLE items (name text, embedding vector(3))")
        conn.execute("INSERT INTO items VALUES ('cat','[1,0,0]'), ('dog','[0.9,0.1,0]'), ('car','[0,0,1]')")
        (nearest,) = conn.execute("SELECT name FROM items ORDER BY embedding <-> '[1,0.05,0]' LIMIT 1").fetchone()
        return f"pgvector nearest neighbour: {nearest}"


def redis_():
    import redis

    r = redis.from_url(env("REDIS_URL", "redis://:redis@localhost:6379/0"), socket_connect_timeout=5)
    return f"counter = {r.incr('examples:python:counter')}"


def s3():
    import boto3
    from botocore.config import Config

    client = boto3.client(
        "s3",
        endpoint_url=env("S3_ENDPOINT", "http://localhost:9000"),
        region_name=env("S3_REGION", "us-east-1"),
        aws_access_key_id=env("S3_ACCESS_KEY", "rustfsadmin"),
        aws_secret_access_key=env("S3_SECRET_KEY", "rustfsadmin"),
        config=Config(s3={"addressing_style": "path"}, retries={"max_attempts": 1}, connect_timeout=5),
    )
    try:
        client.create_bucket(Bucket="examples")
    except client.exceptions.BucketAlreadyOwnedByYou:
        pass
    client.put_object(Bucket="examples", Key="python.txt", Body=b"hello from Python", ContentType="text/plain")
    return "uploaded s3://examples/python.txt"


def smtp():
    msg = EmailMessage()
    msg["From"], msg["To"], msg["Subject"] = "app@example.com", "you@example.com", "Hello from the Python example"
    msg.set_content("It works!")
    with smtplib.SMTP(env("SMTP_HOST", "localhost"), int(env("SMTP_PORT", "1025")), timeout=5) as s:
        s.send_message(msg)
    return "sent - check the Mailpit inbox"


def rabbitmq():
    import pika

    params = pika.URLParameters(env("AMQP_URL", "amqp://rabbit:rabbit@localhost:5672/"))
    with pika.Connection(params, timeout=5) as conn:
        ch = conn.channel()
        ch.queue_declare("examples-python", durable=True)  # RabbitMQ 4 requires shared queues to be durable
        ch.basic_publish("", "examples-python", b"hello from Python")
        for _ in range(50):
            _, _, body = ch.basic_get("examples-python", auto_ack=True)
            if body:
                return f"round-trip: {body.decode()}"
            time.sleep(0.1)
        raise RuntimeError("message not received")


def kafka():
    from confluent_kafka import Consumer, KafkaException, Producer

    brokers, topic = env("KAFKA_BROKERS", "localhost:9092"), "examples-python"
    quiet = {"bootstrap.servers": brokers, "log_level": 0}  # errors are reported by run(), not librdkafka's logger
    producer = Producer({**quiet, "message.timeout.ms": 10000})
    producer.list_topics(timeout=5)  # raises KafkaException(_TRANSPORT) if Kafka isn't running
    errors = []
    producer.produce(topic, b"hello from Python", on_delivery=lambda err, _: err and errors.append(err))
    if producer.flush(12) or errors:
        raise KafkaException(errors[0] if errors else "Connection refused: delivery timed out")

    consumer = Consumer({**quiet, "group.id": f"examples-{uuid.uuid4()}", "auto.offset.reset": "earliest"})
    try:
        consumer.subscribe([topic])
        deadline = time.time() + 40  # a fresh Kafka needs a while for the first consumer group to join
        while time.time() < deadline:
            msg = consumer.poll(1)
            if msg and not msg.error():
                return f"round-trip: {msg.value().decode()}"
        raise RuntimeError("message not received")
    finally:
        consumer.close()


print("docker-files Python example")
for name, fn in [("postgres", postgres), ("redis", redis_), ("s3", s3), ("smtp", smtp), ("rabbitmq", rabbitmq), ("kafka", kafka)]:
    run(name, fn)
sys.exit(1 if failed else 0)
