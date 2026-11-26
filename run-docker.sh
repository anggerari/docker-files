#!/usr/bin/env bash
# Kept for backwards compatibility - prefer `make up`.
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] || { cp .env.example .env; echo "Created .env from .env.example"; }
docker compose up -d "$@"
docker compose ps
