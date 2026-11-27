#!/usr/bin/env bash
# Print connection settings for the active profiles as a .env snippet:
#   make urls                      show them
#   make urls > ../my-app/.env.local
set -euo pipefail
source "$(dirname "$0")/lib.sh"
load_env
h=localhost

echo "# docker-files connection settings (profiles: ${COMPOSE_PROFILES})"
has_profile postgres && cat <<X

# PostgreSQL  |  pgAdmin: http://$h:${PGADMIN_PORT}  (${PGADMIN_EMAIL} / ${PGADMIN_PASSWORD})
DATABASE_URL=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@$h:${POSTGRES_PORT}/${POSTGRES_DB}?sslmode=disable
X
has_profile redis && cat <<X

# Redis  |  RedisInsight: http://$h:${REDISINSIGHT_PORT}
REDIS_URL=redis://:${REDIS_PASSWORD}@$h:${REDIS_PORT}/0
X
has_profile s3 && cat <<X

# S3 (RustFS)  |  console: http://$h:${S3_CONSOLE_PORT}  (${S3_ACCESS_KEY} / ${S3_SECRET_KEY})
S3_ENDPOINT=http://$h:${S3_API_PORT}
S3_REGION=us-east-1
S3_ACCESS_KEY=${S3_ACCESS_KEY}
S3_SECRET_KEY=${S3_SECRET_KEY}
S3_FORCE_PATH_STYLE=true
AWS_ENDPOINT_URL=http://$h:${S3_API_PORT}
AWS_ACCESS_KEY_ID=${S3_ACCESS_KEY}
AWS_SECRET_ACCESS_KEY=${S3_SECRET_KEY}
X
has_profile nsq && cat <<X

# NSQ  |  nsqadmin: http://$h:${NSQADMIN_PORT}
NSQD_ADDRESS=$h:4150
NSQLOOKUPD_HTTP_ADDRESS=$h:4161
X
has_profile mongo && cat <<X

# MongoDB  |  mongo-express: http://$h:${MONGO_EXPRESS_PORT}  (${MONGO_EXPRESS_USER} / ${MONGO_EXPRESS_PASSWORD})
MONGO_URL=mongodb://${MONGO_USER}:${MONGO_PASSWORD}@$h:${MONGO_PORT}/?authSource=admin
X
has_profile mail && cat <<X

# SMTP (Mailpit) - any username/password  |  inbox: http://$h:${MAILPIT_UI_PORT}
SMTP_HOST=$h
SMTP_PORT=${MAILPIT_SMTP_PORT}
SMTP_URL=smtp://$h:${MAILPIT_SMTP_PORT}
X
has_profile qr && cat <<X

# QR generator - GET /?data=<text>&size=<px>
QR_URL=http://$h:${QR_PORT}
X
has_profile kafka && cat <<X

# Kafka  |  Redpanda Console: http://$h:${KAFKA_CONSOLE_PORT}
KAFKA_BROKERS=$h:${KAFKA_PORT}
X
has_profile rabbitmq && cat <<X

# RabbitMQ  |  management UI: http://$h:${RABBITMQ_UI_PORT}  (${RABBITMQ_USER} / ${RABBITMQ_PASSWORD})
AMQP_URL=amqp://${RABBITMQ_USER}:${RABBITMQ_PASSWORD}@$h:${RABBITMQ_PORT}/
X
has_profile search && cat <<X

# Elasticsearch  |  Kibana: http://$h:${KIBANA_PORT}
ELASTICSEARCH_URL=http://$h:${ES_PORT}
X
has_profile keycloak && cat <<X

# Keycloak  |  admin console: http://$h:${KEYCLOAK_PORT}/admin  (${KEYCLOAK_ADMIN} / ${KEYCLOAK_ADMIN_PASSWORD})
# test user: dev / dev   clients: "app" (public, PKCE), "api" (secret: api-secret)
OIDC_ISSUER=http://$h:${KEYCLOAK_PORT}/realms/dev
OIDC_CLIENT_ID=app
X
has_profile observability && cat <<X

# Observability  |  Grafana: http://$h:${GRAFANA_PORT}  (${GRAFANA_USER} / ${GRAFANA_PASSWORD})
PROMETHEUS_URL=http://$h:${PROMETHEUS_PORT}
LOKI_URL=http://$h:${LOKI_PORT}
OTEL_EXPORTER_PROMETHEUS_URL=http://$h:${PROMETHEUS_PORT}/api/v1/write
X
exit 0
