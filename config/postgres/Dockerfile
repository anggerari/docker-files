# PostGIS + pgvector in one image.
# postgis/postgis only publishes amd64, so on Apple Silicon this runs via
# emulation (Rosetta) - see `platform:` in docker-compose.yaml.
ARG PG_MAJOR=17
ARG POSTGIS_VERSION=3.7
FROM postgis/postgis:${PG_MAJOR}-${POSTGIS_VERSION}
ARG PG_MAJOR
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-${PG_MAJOR}-pgvector \
 && rm -rf /var/lib/apt/lists/*
