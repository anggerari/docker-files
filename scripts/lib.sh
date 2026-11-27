#!/usr/bin/env bash
# Shared helpers for the scripts in this folder. Works with macOS's bash 3.2.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

ALL_PROFILES="postgres redis s3 nsq mongo mail qr kafka rabbitmq search keycloak observability"

# description | idle RAM (MB) | disk used by images (MB)
# Measured on an Apple Silicon Mac with default settings; your numbers will vary.
profile_info() {
  case "$1" in
    postgres)      echo "PostgreSQL 17 + PostGIS + pgvector, pgAdmin|300|1630" ;;
    redis)         echo "Redis 8, RedisInsight|280|1010" ;;
    s3)            echo "RustFS - S3-compatible storage + console|20|450" ;;
    nsq)           echo "NSQ message queue + nsqadmin|10|90" ;;
    mongo)         echo "MongoDB 8, mongo-express|150|1550" ;;
    mail)          echo "Mailpit - catch-all SMTP + web inbox|10|50" ;;
    qr)            echo "QR code generator API|5|15" ;;
    kafka)         echo "Kafka 4 (KRaft) + Redpanda Console|360|960" ;;
    rabbitmq)      echo "RabbitMQ 4 + management UI|150|280" ;;
    search)        echo "Elasticsearch 9 + Kibana|2140|4130" ;;
    keycloak)      echo "Keycloak (OIDC/SSO) with a dev realm|570|750" ;;
    observability) echo "Grafana, Prometheus, Loki, Alloy|450|3310" ;;
    *) return 1 ;;
  esac
}
profile_field() { profile_info "$1" | cut -d'|' -f"$2"; }

# Load settings with the same precedence as Docker Compose:
# shell environment > .env > .env.example
load_env() {
  local f line key val
  for f in .env .env.example; do
    [ -f "$f" ] || continue
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in ''|\#*) continue ;; esac
      key="${line%%=*}"; val="${line#*=}"
      case "$key" in *[!A-Za-z0-9_]*|'') continue ;; esac
      if [ -z "${!key+x}" ]; then export "$key=$val"; fi
    done < "$f"
  done
}

# Profiles that are switched on (COMPOSE_PROFILES, "*" = all)
active_profiles() {
  local p="${COMPOSE_PROFILES:-}"
  if [ "$p" = "*" ]; then echo "$ALL_PROFILES"; else echo "$p" | tr ',' ' '; fi
}

has_profile() { case " $(active_profiles) " in *" $1 "*) return 0 ;; esac; return 1; }

# Set KEY=VALUE in .env (replace or append)
set_env() {
  local key="$1" val="$2" tmp
  tmp="$(mktemp)"
  if grep -q "^${key}=" .env 2>/dev/null; then
    awk -v k="$key" -v v="$val" 'index($0, k"=")==1 {print k"="v; next} {print}' .env > "$tmp" && mv "$tmp" .env
  else
    rm -f "$tmp"; echo "${key}=${val}" >> .env
  fi
}

docker_mem_mb() { echo $(( $(docker info --format '{{.MemTotal}}' </dev/null 2>/dev/null || echo 0) / 1024 / 1024 )); }
free_disk_mb()  { df -Pk "$ROOT" | awk 'NR==2 {print int($4/1024)}'; }

human_mb() { if [ "$1" -ge 1000 ]; then awk -v m="$1" 'BEGIN{printf "%.1f GB", m/1024}'; else echo "$1 MB"; fi; }

if [ -t 1 ]; then B=$'\033[1m'; D=$'\033[2m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; C=$'\033[36m'; N=$'\033[0m'
else B=; D=; G=; Y=; R=; C=; N=; fi
