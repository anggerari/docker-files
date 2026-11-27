## What does this change?

<!-- e.g. "feat: add ClickHouse with Tabix UI" -->

## Checklist

- [ ] PR title follows [Conventional Commits](https://www.conventionalcommits.org) (`feat:`, `fix:`, `docs:`, `chore:`)
- [ ] New service: own profile, pinned image tag, health check, ports bound to `${BIND_ADDR:-127.0.0.1}`
- [ ] Settings added to `.env.example`; README services table updated
- [ ] `scripts/check.sh` and `scripts/lib.sh` updated for new profiles
- [ ] `COMPOSE_PROFILES=<profile> docker compose up -d --wait && make check` passes locally
