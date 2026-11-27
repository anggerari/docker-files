# PostGIS + pgvector in one image.
# postgis/postgis only publishes amd64, so on Apple Silicon this runs via
# emulation (Rosetta) - see `platform:` in docker-compose.yaml.
FROM postgis/postgis:17-3.7
# PG_MAJOR is set by the base image
RUN apt-get update \
 && apt-get install -y --no-install-recommends "postgresql-${PG_MAJOR}-pgvector" \
 && rm -rf /var/lib/apt/lists/*
