#!/usr/bin/env bash
# One-line install:
#   curl -fsSL https://raw.githubusercontent.com/anggerari/docker-files/main/install.sh | bash
# Options (env vars):  DIR=my-stack  PROFILES=postgres,redis  NO_START=1  REPO=<fork url>
set -euo pipefail

REPO="${REPO:-https://github.com/anggerari/docker-files}"
DIR="${DIR:-docker-files}"

say()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

command -v docker >/dev/null || fail "Docker is not installed: https://docs.docker.com/get-docker/"
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 is required (the 'docker compose' command)."
docker info >/dev/null 2>&1 || fail "Docker is installed but not running. Start Docker Desktop / the docker service first."

if [ -e "$DIR" ]; then
  fail "'$DIR' already exists. Use DIR=another-name, or cd into it and run 'make up'."
fi

say "Downloading docker-files into ./$DIR"
if command -v git >/dev/null; then
  git clone --depth 1 --quiet "$REPO.git" "$DIR"
else
  mkdir -p "$DIR" && curl -fsSL "$REPO/archive/refs/heads/main.tar.gz" | tar -xz -C "$DIR" --strip-components 1
fi
cd "$DIR"
cp .env.example .env

# Pick services: interactive if we have a terminal (even under curl | bash)
if [ -n "${PROFILES:-}" ]; then
  scripts/init.sh --profiles "$PROFILES"
elif [ -r /dev/tty ] && [ -t 1 ]; then
  scripts/init.sh < /dev/tty
else
  scripts/init.sh --profiles postgres,redis
fi

if [ -n "${NO_START:-}" ]; then
  say "Done. Start it with: cd $DIR && docker compose up -d --wait"
  exit 0
fi

say "Starting services (first run downloads images, this can take a few minutes)"
docker compose up -d --build --wait
echo
scripts/urls.sh
echo
say "Done! You're in ./$DIR - try 'make help' (or 'docker compose ps' if you don't have make)."
