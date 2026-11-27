# Examples

The same program in three languages: connect to every docker-files service that's running, do one real operation on each, and skip the rest.

| Service | What it does | Go | Node.js | Python |
| --- | --- | --- | --- | --- |
| Postgres | pgvector nearest-neighbour query | pgx | pg | psycopg 3 |
| Redis | increment a counter | go-redis | redis | redis-py |
| S3 (RustFS) | create bucket, upload a file | minio-go | AWS SDK v3 | boto3 |
| SMTP (Mailpit) | send an email | net/smtp | nodemailer | smtplib |
| RabbitMQ | publish + consume | amqp091-go | amqplib | pika |
| Kafka | produce + consume | franz-go | kafkajs | confluent-kafka |

```sh
make up p=postgres,redis,s3,mail,rabbitmq,kafka   # from the repo root

cd examples/go     && go run .
cd examples/node   && npm install && npm start
cd examples/python && pip install -r requirements.txt && python main.py
```

Settings come from environment variables with the stack's defaults built in, so they work out of the box. If you changed ports or passwords, load them first:

```sh
set -a; eval "$(make -s -C ../.. urls)"; set +a
```

CI runs all three against the real services on every change.
