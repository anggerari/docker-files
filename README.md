# docker-files

**Your whole backend stack on your laptop, one command away.**
Postgres (PostGIS + pgvector), Redis, S3, Kafka, RabbitMQ, Elasticsearch, Keycloak, Grafana, MongoDB, a fake SMTP inbox and more — each with its admin UI, health checks and sane defaults. Start only what your project needs, even on an 8 GB laptop.

[![smoke-test](https://github.com/anggerari/docker-files/actions/workflows/smoke-test.yml/badge.svg)](https://github.com/anggerari/docker-files/actions/workflows/smoke-test.yml)
[![release](https://img.shields.io/github/v/release/anggerari/docker-files)](https://github.com/anggerari/docker-files/releases)
![license](https://img.shields.io/badge/license-MIT-blue)
![docker compose](https://img.shields.io/badge/docker%20compose-v2-2496ED?logo=docker&logoColor=white)

```sh
curl -fsSL https://raw.githubusercontent.com/anggerari/docker-files/main/install.sh | bash
```

The installer checks Docker, lets you tick the services you want (showing how much RAM and disk they need), starts them, and prints the connection strings for your app. [Read it first](install.sh) if you like — it's short.

Prefer git?

```sh
git clone https://github.com/anggerari/docker-files.git && cd docker-files
make init   # pick services
make up     # start them, wait until healthy
make urls   # connection strings for your app
```

---

## Why use this

- **Pick what you run.** Every service is a [Compose profile](https://docs.docker.com/compose/how-tos/profiles/). `make init` shows a checklist with RAM and disk per service, so you know what you're getting into.
- **Ready when it says it's ready.** Every service has a health check and `make up` waits for them, so migrations don't race a half-started database. `make check` goes further and does a real write/read on each one.
- **Copy-paste connection strings.** `make urls > ../my-app/.env.local` and your app is configured.
- **Runs on modest machines.** Small memory defaults, a low-memory mode, and commands to see and free disk space. See [Low-spec machines](#running-on-a-low-spec-machine).
- **Safe by default.** Ports bind to `127.0.0.1`, so your dev databases aren't exposed to the café Wi-Fi.
- **Keeps itself up to date.** Image versions are pinned; Dependabot opens PRs for new versions, and CI boots every service (and runs the [examples](examples/)) before anything is merged. A weekly run catches upstream images that break or disappear.
- **Pre-wired.** pgAdmin already knows your Postgres, RedisInsight your Redis, Grafana its datasources, Keycloak ships a ready `dev` realm with a test user, and Grafana shows the logs of every container.

## Services

RAM is measured idle with default settings; disk is the size of the images. Both on an Apple Silicon Mac — yours will differ a bit.

| Profile | What you get | Ports | RAM | Disk |
| --- | --- | --- | ---: | ---: |
| `postgres` | PostgreSQL 17 + PostGIS 3.7 + pgvector, **pgAdmin** | 5432, UI 5050 | ~300 MB | ~1.6 GB |
| `redis` | Redis 8.6, **RedisInsight** | 6379, UI 5540 | ~280 MB | ~1.0 GB |
| `s3` | [RustFS](https://github.com/rustfs/rustfs) S3-compatible storage + console | 9000, UI 9001 | ~20 MB | ~450 MB |
| `nsq` | NSQ (nsqlookupd, nsqd), **nsqadmin** | 4150-4161, UI 4171 | ~10 MB | ~90 MB |
| `mongo` | MongoDB 8.0, **mongo-express** | 27017, UI 8081 | ~150 MB | ~1.6 GB |
| `mail` | [Mailpit](https://mailpit.axllent.org) catch-all SMTP + web inbox | SMTP 1025, UI 8025 | ~10 MB | ~50 MB |
| `qr` | QR code generator API | 9010 | ~5 MB | ~15 MB |
| `kafka` | Kafka 4.4 (KRaft, no ZooKeeper), **Redpanda Console** | 9092, UI 8088 | ~360 MB | ~960 MB |
| `rabbitmq` | RabbitMQ 4.4 + management UI | 5672, UI 15672 | ~150 MB | ~280 MB |
| `search` | Elasticsearch 9.5, **Kibana** | 9200, UI 5601 | ~2.1 GB | ~4.1 GB |
| `keycloak` | Keycloak 26 (OIDC/SSO) with a `dev` realm | 8080 | ~570 MB | ~750 MB |
| `observability` | **Grafana**, Prometheus, Loki, Alloy (ships every container's logs to Loki) | UI 3000, 9090, 3100 | ~450 MB | ~3.3 GB |

### Logins and connection strings

`make urls` prints these for the profiles you run, as a ready-to-use `.env` snippet. The defaults:

| Service | Connect with | Login |
| --- | --- | --- |
| Postgres | `postgres://postgres:postgres@localhost:5432/app` | pgAdmin: `admin@example.com` / `admin` |
| Redis | `redis://:redis@localhost:6379/0` | — |
| S3 | endpoint `http://localhost:9000`, path-style | `rustfsadmin` / `rustfsadmin` |
| MongoDB | `mongodb://mongo:mongo@localhost:27017/?authSource=admin` | mongo-express: `admin` / `admin` |
| SMTP | `localhost:1025`, no TLS | any username / password |
| Kafka | brokers `localhost:9092` | — |
| RabbitMQ | `amqp://rabbit:rabbit@localhost:5672/` | UI: `rabbit` / `rabbit` |
| Elasticsearch | `http://localhost:9200` (security off) | — |
| Keycloak | issuer `http://localhost:8080/realms/dev` | admin console `admin` / `admin`; test user `dev` / `dev`; clients `app` (public, PKCE) and `api` (secret `api-secret`) |
| Grafana | http://localhost:3000 | `admin` / `admin` |

Every port, password and memory setting lives in [`.env.example`](.env.example).

## Commands

```sh
make init                  # pick services (checklist with RAM/disk), writes .env
make up                    # start the profiles in .env, wait until healthy
make up p=postgres,kafka   # start specific profiles
make only s="postgres redis"   # just these containers, no admin UIs (saves RAM)
make urls                  # connection strings (make urls > ../app/.env.local)
make check                 # verify each running service really works
make ps | logs s=kafka     # status / follow logs
make stats                 # live RAM and CPU per container
make disk                  # disk used by images and this stack's data
make down                  # stop (data is kept)
make clean                 # stop and delete all data (asks first)
make uninstall             # also delete this stack's images (frees the most disk)
make help                  # everything else
```

No `make` (e.g. plain Windows)? Use Compose directly:

```sh
docker compose --profile postgres --profile redis up -d --wait
COMPOSE_PROFILES='*' docker compose down
```

## Running on a low-spec machine

The stack is built for laptops, but Docker itself needs headroom. Rough guide:

| RAM given to Docker | What runs comfortably |
| --- | --- |
| **2 GB** | 2-3 light profiles: `postgres`, `redis`, `s3`, `mail`, `nsq`, `rabbitmq` — use `make only` to skip the UIs |
| **4 GB** | Most combinations, e.g. `postgres,redis,s3,kafka,mail` with UIs. Leave out `search`, or run it in low-memory mode on its own. |
| **8 GB+** | Everything: `make all` uses about 4.5 GB idle |

**1. Turn on low-memory mode.** `make init` offers it automatically when Docker has less than 6 GB or your selection is tight. It sets:

| Setting | Default | Low-memory |
| --- | --- | --- |
| `REDIS_MAXMEMORY` | 256mb | 64mb |
| `MONGO_CACHE_GB` | 0.25 | 0.1 |
| `KAFKA_HEAP` | 512m | 256m |
| `ES_HEAP` | 512m | 256m |
| `KIBANA_HEAP_MB` | 768 | 512 |
| `KEYCLOAK_HEAP` | 512m | 256m |

**2. Skip the admin UIs.** They often use more RAM than the service itself (RedisInsight, Kibana, pgAdmin). `make only s="postgres redis"` starts just the databases.

**3. Run what you need today.** `make down`, then `make up p=...` with a different set. Data stays in volumes, so switching is cheap.

**4. Watch it.** `make stats` shows live memory per container.

**5. Give Docker the right amount.** Docker Desktop: *Settings → Resources → Memory*. OrbStack and Linux use memory dynamically and return it when idle.

**Heaviest services**: `search` (Elasticsearch + Kibana, ~2.1 GB) and `keycloak` (~570 MB). Need Elasticsearch but not Kibana? `make only s=elasticsearch` with `ES_HEAP=256m`.

## Running low on disk

Images are the big cost — the full stack is ~14 GB. To keep it small:

- **Only pull what you use.** Images download the first time a profile starts. `make init` shows the disk each profile needs and warns you if you don't have enough free.
- **`make disk`** shows what Docker and this stack's data volumes use.
- **`make prune`** removes dangling images and build cache. Safe: it doesn't touch your other images or any data.
- **`make uninstall`** removes this stack's containers, data and images — everything it put on your disk.
- **Logs and history are capped**: Kafka keeps messages 24 h (`KAFKA_RETENTION_HOURS`), Loki keeps logs 3 days, Prometheus keeps metrics 3 days (`PROMETHEUS_RETENTION`), Mailpit keeps the last 5,000 emails (`MAILPIT_MAX_MESSAGES`).
- **Elasticsearch won't go read-only** when your disk is >90% full (its usual safety switch is off here, since that's normal on a laptop).
- **Biggest images**: `search` (~4 GB), `observability` (~3.3 GB), `postgres` (~1.6 GB, PostGIS), `mongo` (~1.6 GB).
- On a Mac, Docker keeps images inside one virtual disk file. OrbStack shrinks it automatically after you delete images (give it a few minutes); Docker Desktop may take longer to give the space back.

## Examples

[`examples/`](examples/) has small programs in **Go**, **Node.js** and **Python** that connect to Postgres (with a pgvector query), Redis, S3, SMTP, RabbitMQ and Kafka, do one real operation on each, and skip whatever isn't running. They're run in CI against the real stack, so they stay correct.

```sh
make up p=postgres,redis,s3,mail,rabbitmq,kafka
cd examples/go && go run .
```

```
docker-files Go example
  ✓ postgres  pgvector nearest neighbour: cat
  ✓ redis     counter = 1
  ✓ s3        uploaded s3://examples/go.txt
  ✓ smtp      sent - check the Mailpit inbox
  ✓ rabbitmq  round-trip: hello from Go
  ✓ kafka     round-trip: 1 record(s) read back
```

## Recipes

**Load a SQL dump or create extra databases on first start** — drop `.sql`, `.sql.gz` or `.sh` files into [`config/postgres/init/`](config/postgres/init/). They run once, when the volume is first created. (`*.sql` files are git-ignored, so your dumps never get committed.)

**Restore a dump into a running database**

```sh
docker compose exec -T postgres psql -U postgres -d app < my_dump.sql
```

**Use pgvector**

```sql
CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(3));
INSERT INTO items (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');
SELECT * FROM items ORDER BY embedding <-> '[3,1,2]' LIMIT 5;
```

**Use S3 from the AWS CLI**

```sh
export AWS_ACCESS_KEY_ID=rustfsadmin AWS_SECRET_ACCESS_KEY=rustfsadmin
aws --endpoint-url http://localhost:9000 s3 mb s3://my-bucket
aws --endpoint-url http://localhost:9000 s3 cp ./file.txt s3://my-bucket/
```

**Log in with Keycloak** — the `dev` realm is ready: point your app's OIDC settings at `http://localhost:8080/realms/dev` with client `app`, and log in as `dev` / `dev`. The realm sends its emails (password reset, verification) to Mailpit, so run the `mail` profile alongside it to see them.

**See your containers' logs in Grafana** — start `observability`, open [Grafana](http://localhost:3000) → *Explore* → *Loki*, and query `{service="postgres"}` (or any container). To scrape your own app's metrics, uncomment the example in [`config/prometheus/prometheus.yml`](config/prometheus/prometheus.yml).

**Catch outgoing email** — point your app's SMTP at `localhost:1025` (no TLS, any username/password). Every email shows up at [localhost:8025](http://localhost:8025) instead of reaching real people.

**Expose services to your network** (e.g. to test from a phone) — set `BIND_ADDR=0.0.0.0` in `.env`. **Change the default passwords first.**

## FAQ

**Why RustFS instead of MinIO?**
MinIO stopped publishing its community Docker images, so `minio/minio` can no longer be pulled. [RustFS](https://github.com/rustfs/rustfs) is an Apache-2.0, S3-compatible replacement with a web console, on the same ports (9000/9001).

**Postgres is slow to start on my M1/M2/M3 Mac.**
The official `postgis/postgis` image is amd64-only, so on Apple Silicon it runs through Rosetta emulation. It works fine for development; the first build takes a minute or two.

**Port already in use?**
Change it in `.env` (e.g. `KEYCLOAK_PORT=8180`) and run `make up` again.

**Alloy mounts the Docker socket — is that safe?**
It's mounted read-only and only used to read container logs. If you'd rather not, don't run the `observability` profile, or remove the `alloy` service.

**Why is the QR service built locally?**
The original `samwierema/go-qr-generator` image (2015) uses a manifest format current Docker can't pull. [`config/qr/Dockerfile`](config/qr/Dockerfile) builds the same service from source into a tiny distroless image. The API is unchanged.

**Where is my data?**
In Docker named volumes (`make disk` lists them). `make down` keeps them; `make clean` deletes them.

## Contributing

New services, fixes and docs are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Looking for a place to start? Check the [good first issues](https://github.com/anggerari/docker-files/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22).

## License

[MIT](LICENSE) © Angger Pangestu Ari
