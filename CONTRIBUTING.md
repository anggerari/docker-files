# Contributing

Thanks for helping! The most common contribution is **adding a service**, so this guide focuses on that.

## Adding a service

1. **docker-compose.yaml** - add the service (and its admin UI, if it has a good one) under a new profile:
   - a **pinned** image tag (no `latest`), so Dependabot can open update PRs
   - a `healthcheck` if the image has a shell/curl/wget (otherwise say why in a comment)
   - ports as `"${BIND_ADDR:-127.0.0.1}:${MYSVC_PORT:-1234}:1234"`
   - data in a named volume, declared at the bottom of the file
   - memory knobs (heap size, cache size) as env vars with laptop-friendly defaults
2. **.env.example** - add every setting with its default value.
3. **scripts/lib.sh** - add the profile to `ALL_PROFILES` and `profile_info` (description, idle RAM in MB from `make stats`, image disk size in MB from `docker image ls`).
4. **scripts/check.sh** - add a check that does something real (write + read), not just "port is open".
5. **scripts/urls.sh** - print the connection string(s) apps need.
6. **README.md** - add a row to the services table.
7. **.github/workflows/smoke-test.yml** - add the profile to the matrix.

Then verify:

```sh
COMPOSE_PROFILES=myprofile docker compose up -d --wait
COMPOSE_PROFILES=myprofile make check
COMPOSE_PROFILES=myprofile docker compose down -v
```

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org): `feat: add clickhouse`, `fix(kafka): advertise correct port`, `docs: ...`, `chore(deps): ...`.

## Low-spec friendly

Keep defaults small - many people run this on 8 GB laptops. If a service needs more than ~500 MB idle, expose a heap/cache setting and add a low-memory value to `scripts/init.sh`.
