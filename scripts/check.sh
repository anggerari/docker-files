#!/usr/bin/env bash
# Check that each active profile actually works (not just "container is up").
#   make check            all active profiles
#   make check p=kafka    one profile
set -uo pipefail
source "$(dirname "$0")/lib.sh"
load_env
h=127.0.0.1; fails=0
dc() { docker compose "$@"; }

ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$1"; }
bad()  { printf '  %s✗%s %s\n' "$R" "$N" "$1"; fails=$((fails+1)); }
# try a command for up to N seconds (UIs can take a while after "healthy")
try()  { local name="$1" secs="$2"; shift 2; local end=$((SECONDS+secs))
         while :; do if "$@" >/dev/null 2>&1; then ok "$name"; return; fi
           [ $SECONDS -ge $end ] && { bad "$name"; return; }; sleep 2; done; }
http() { curl -fsS -o /dev/null --max-time 5 "$@"; }

for p in $(active_profiles); do
  printf '%s%s%s\n' "$B" "$p" "$N"
  case "$p" in
    postgres)
      try "postgres: postgis + pgvector enabled" 30 sh -c \
        "docker compose exec -T postgres psql -U '$POSTGRES_USER' -d '$POSTGRES_DB' -tAc \"select count(*) from pg_extension where extname in ('postgis','vector')\" | grep -qx 2"
      try "pgadmin UI" 90 http "http://$h:$PGADMIN_PORT/misc/ping" ;;
    redis)
      try "redis: PING" 30 sh -c "docker compose exec -T redis redis-cli ping | grep -q PONG"
      try "redisinsight UI" 60 http "http://$h:$REDISINSIGHT_PORT/api/health" ;;
    s3)
      try "rustfs: S3 API" 30 http "http://$h:$S3_API_PORT/health"
      try "rustfs: console" 30 http "http://$h:$S3_CONSOLE_PORT/rustfs/console/health" ;;
    nsq)
      try "nsqd: publish a message" 30 http -d hello "http://$h:4151/pub?topic=docker-files-check"
      try "nsqadmin UI" 30 http "http://$h:$NSQADMIN_PORT/" ;;
    mongo)
      try "mongo: ping" 30 sh -c "docker compose exec -T mongo mongosh -u '$MONGO_USER' -p '$MONGO_PASSWORD' --quiet --eval 'db.adminCommand(\"ping\").ok' | grep -q 1"
      try "mongo-express UI" 60 http -u "$MONGO_EXPRESS_USER:$MONGO_EXPRESS_PASSWORD" "http://$h:$MONGO_EXPRESS_PORT/" ;;
    mail)
      try "mailpit: ready" 30 http "http://$h:$MAILPIT_UI_PORT/readyz" ;;
    qr)
      try "qr: returns a PNG" 30 sh -c "curl -fsS -o /dev/null -w '%{content_type}' 'http://$h:$QR_PORT/?data=check' | grep -q image/png" ;;
    kafka)
      try "kafka: create + list topic" 60 sh -c \
        "docker compose exec -T kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --create --if-not-exists --topic docker-files-check >/dev/null && docker compose exec -T kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list | grep -q docker-files-check"
      try "redpanda console UI" 60 http "http://$h:$KAFKA_CONSOLE_PORT/" ;;
    rabbitmq)
      try "rabbitmq: management API" 60 http -u "$RABBITMQ_USER:$RABBITMQ_PASSWORD" "http://$h:$RABBITMQ_UI_PORT/api/overview" ;;
    search)
      try "elasticsearch: cluster health" 60 http "http://$h:$ES_PORT/_cluster/health?wait_for_status=yellow"
      try "kibana UI" 120 sh -c "curl -fsS http://$h:$KIBANA_PORT/api/status | grep -q '\"level\":\"available\"'" ;;
    keycloak)
      try "keycloak: dev realm OIDC discovery" 90 http "http://$h:$KEYCLOAK_PORT/realms/dev/.well-known/openid-configuration"
      try "keycloak: log in as dev/dev" 30 sh -c \
        "curl -fsS -d grant_type=password -d client_id=app -d username=dev -d password=dev http://$h:$KEYCLOAK_PORT/realms/dev/protocol/openid-connect/token | grep -q access_token" ;;
    observability)
      try "prometheus: ready" 30 http "http://$h:$PROMETHEUS_PORT/-/ready"
      try "grafana: datasources provisioned" 60 sh -c \
        "curl -fsS -u '$GRAFANA_USER:$GRAFANA_PASSWORD' http://$h:$GRAFANA_PORT/api/datasources | grep -q loki"
      try "loki: receiving container logs from alloy" 120 sh -c \
        "curl -fsS -G http://$h:$LOKI_PORT/loki/api/v1/labels | grep -q container" ;;
    *) bad "unknown profile '$p'" ;;
  esac
done

[ $fails -eq 0 ] && printf '\n%sAll checks passed.%s\n' "$G" "$N" || printf '\n%s%d check(s) failed.%s Try: make logs s=<service>\n' "$R" "$fails" "$N"
exit $((fails > 0))
