# docker-files

**One `docker compose` file for every backend service you need on your laptop.**
Postgres (with PostGIS + pgvector), Redis, S3-compatible storage, NSQ, MongoDB, a fake SMTP inbox — each with its admin UI, health checks, and sane defaults. Start only what your project needs.

[![smoke-test](https://github.com/anggerari/docker-files/actions/workflows/smoke-test.yml/badge.svg)](https://github.com/anggerari/docker-files/actions/workflows/smoke-test.yml)
![license](https://img.shields.io/badge/license-MIT-blue)
![docker compose](https://img.shields.io/badge/docker%20compose-v2-2496ED?logo=docker&logoColor=white)

```sh
git clone https://github.com/anggerari/docker-files.git && cd docker-files
make up p=postgres,redis
```

That's it — Postgres on `localhost:5432`, pgAdmin on [localhost:5050](http://localhost:5050), Redis on `6379`, RedisInsight on [localhost:5540](http://localhost:5540).

---

## Why use this

- **Pick what you run.** Every service is a [Compose profile](https://docs.docker.com/compose/how-tos/profiles/). No more 11 containers eating your RAM when you only need Postgres.
- **Ready when it says it's ready.** Every database has a health check, and `make up` waits until they pass — so your app or migrations don't race a half-started DB.
- **Works with zero config.** Every setting has a default. Copy `.env.example` to `.env` only when you want to change something.
- **Safe by default.** Ports bind to `127.0.0.1`, so your dev databases aren't exposed to the café Wi-Fi.
- **Pinned versions.** No surprise breakage from `:latest`. A weekly CI job boots the whole stack to catch upstream images that break or disappear.
- **Pre-wired admin UIs.** pgAdmin already knows about Postgres, RedisInsight already knows about Redis.

## Services

| Profile    | Service           | Port(s)         | UI / connection                                   | Default login                  |
| ---------- | ----------------- | --------------- | ------------------------------------------------- | ------------------------------ |
| `postgres` | PostgreSQL 17 + PostGIS 3.7 + pgvector | 5432 | `postgres://postgres:postgres@localhost:5432/app` | `postgres` / `postgres`        |
| `postgres` | pgAdmin 4         | 5050            | http://localhost:5050                             | `admin@example.com` / `admin`  |
| `redis`    | Redis 8.6         | 6379            | `redis://:redis@localhost:6379`                   | password `redis`               |
| `redis`    | RedisInsight 3    | 5540            | http://localhost:5540                             | —                              |
| `s3`       | [RustFS](https://github.com/rustfs/rustfs) (S3 API) | 9000 | `http://localhost:9000`                 | `rustfsadmin` / `rustfsadmin`  |
| `s3`       | RustFS console    | 9001            | http://localhost:9001                             | `rustfsadmin` / `rustfsadmin`  |
| `nsq`      | nsqlookupd / nsqd | 4160-4161 / 4150-4151 | `localhost:4150` (TCP), `localhost:4151` (HTTP) | —                        |
| `nsq`      | nsqadmin          | 4171            | http://localhost:4171                             | —                              |
| `mongo`    | MongoDB 8.0       | 27017           | `mongodb://mongo:mongo@localhost:27017`           | `mongo` / `mongo`              |
| `mongo`    | mongo-express     | 8081            | http://localhost:8081                             | `admin` / `admin`              |
| `mail`     | [Mailpit](https://mailpit.axllent.org) | 1025 (SMTP) / 8025 | http://localhost:8025 — SMTP at `localhost:1025` | any user / any password |
| `qr`       | QR code generator | 9010            | http://localhost:9010/?data=hello&size=300        | —                              |

Every port and password can be changed in `.env`.

## Usage

```sh
make up                    # start the profiles in .env (default: postgres,redis)
make up p=postgres,s3      # start specific profiles
make all                   # start everything
make ps                    # what's running
make logs s=postgres       # follow one service's logs
make down                  # stop (data is kept)
make clean                 # stop AND delete all data (asks first)
make help                  # list all commands
```

No `make`? Use Compose directly:

```sh
docker compose --profile postgres --profile redis up -d --wait
COMPOSE_PROFILES='*' docker compose down
```

### Choosing your default services

```sh
cp .env.example .env
```

Then edit `COMPOSE_PROFILES` in `.env`:

```env
COMPOSE_PROFILES=postgres,redis,s3
```

Now plain `make up` (or `docker compose up -d`) starts exactly those.

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

**Use RustFS from the AWS CLI**

```sh
export AWS_ACCESS_KEY_ID=rustfsadmin AWS_SECRET_ACCESS_KEY=rustfsadmin
aws --endpoint-url http://localhost:9000 s3 mb s3://my-bucket
aws --endpoint-url http://localhost:9000 s3 cp ./file.txt s3://my-bucket/
```

Any S3 SDK works the same way — point the endpoint at `http://localhost:9000` and enable path-style addressing.

**Catch outgoing email** — point your app's SMTP settings at `localhost:1025` (no TLS, any username/password). Every email shows up in the Mailpit inbox at [localhost:8025](http://localhost:8025) instead of reaching real people.

**Expose services to your network** (e.g. to test from a phone) — set `BIND_ADDR=0.0.0.0` in `.env`. **Change the default passwords first.**

## FAQ

**Why RustFS instead of MinIO?**
MinIO stopped publishing its community Docker images, so `minio/minio` can no longer be pulled. [RustFS](https://github.com/rustfs/rustfs) is an Apache-2.0, S3-compatible replacement with a web console, on the same ports (9000/9001).

**Postgres is slow to start on my M1/M2/M3 Mac.**
The official `postgis/postgis` image is amd64-only, so on Apple Silicon it runs through Rosetta emulation. It works fine for development; the first build just takes a minute.

**Why is the QR service built locally?**
The original `samwierema/go-qr-generator` image (2015) uses a manifest format current Docker can't pull. [`config/qr/Dockerfile`](config/qr/Dockerfile) builds the same service from source into a tiny distroless image. The API is unchanged.

**Where is my data?**
In Docker named volumes (`docker volume ls | grep docker-files`). `make down` keeps them; `make clean` deletes them.

## Contributing

Want another service (Kafka, RabbitMQ, Elasticsearch, Keycloak, …)? PRs are welcome. Please:

1. Add it under its own profile, with pinned image tag, a health check where possible, and ports bound to `${BIND_ADDR}`.
2. Add its settings to `.env.example` and a row to the table above.
3. Make sure `COMPOSE_PROFILES='*' docker compose up -d --wait` passes — CI runs the same thing.

## License

[MIT](LICENSE) © Angger Pangestu Ari
