# NOTICE — Chatwoot template

This is a community template. It is not affiliated with or endorsed by Chatwoot Inc.

## Upstream sources checked (2026-10-11)

| Source | Version / path | License | Use |
|---|---|---|---|
| chatwoot/chatwoot | `v4.18.0`: `docker-compose.production.yaml`, `.env.example`, `config/storage.yml`, `config/database.yml`, `config/puma.rb`, `docker/Dockerfile`, `docker/entrypoints/rails.sh` | MIT (outside `enterprise/`) | Topology (rails + sidekiq + pgvector Postgres + Redis), variable names, `s3_compatible` storage keys, start commands |
| chatwoot/chatwoot | `v4.18.0`: `db/schema.rb`, `app/models/installation_config.rb`, `lib/global_config_service.rb`, `lib/llm/config.rb`, `config/initializers/ai_agents.rb`, `app/controllers/api_controller.rb`, `app/controllers/health_controller.rb` | MIT | pgvector requirement, how Captain/sign-up settings are stored, health endpoints |
| chatwoot/chatwoot | `LICENSE`, `enterprise/LICENSE` | MIT / Chatwoot Enterprise License | Licensing note on Captain AI |
| Railway docs | Storage Buckets, Outbound Networking (SMTP on Pro only), pre-deploy command | — | Storage and email design |

## Market templates and repos reviewed

| Code / repo | License | Use |
|---|---|---|
| `chatwoot` (image `ghcr.io/railwayapp-templates/chatwoot:Community`) | n/a | Reviewed service layout; not reused |
| `self-host-chatwoot` (image-based) | n/a | Reviewed; identified the separate-volume problem |
| `chatwoot-1` → github.com/Amritasha/chatwoot-railway-template | none (all rights reserved) | Read only; nothing copied |

## Railway base services

`Postgres` variables and volume layout copied from `templates/_railway-base/postgres.json` (image swapped to `pgvector/pgvector:0.8.7-pg16`, `SSL_CERT_DAYS` removed); `Redis` from `templates/_railway-base/redis.json`.

## Runtime images

- `chatwoot/chatwoot:v4.18.0` — Chatwoot's standard image; contains MIT code and, in `enterprise/`, code under the Chatwoot Enterprise License (production use of enterprise features such as Captain requires a Chatwoot subscription). `chatwoot/chatwoot:v4.18.0-ce` is the MIT-only alternative.
- `pgvector/pgvector:0.8.7-pg16` (PostgreSQL License), `redis:8.2`.

All files in `template/` (scripts, Dockerfile, documentation) were written for this template.
