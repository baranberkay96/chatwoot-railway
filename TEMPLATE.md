# Chatwoot v4 Omnichannel Support Desk — composer spec

| Field | Value |
|---|---|
| Listing name | **Chatwoot v4 Omnichannel Support Desk** (version label `v4` = Chatwoot major; tags are `v4.18.0`) |
| Description | Live chat, email, WhatsApp Cloud API and social inbox with AI assist and workers. (81 chars, unchanged — see caveats under Open questions) |
| Category | Automation |
| Tags | chatwoot, customer-support, live-chat, helpdesk, omnichannel, intercom-alternative |
| Base market template | `chatwoot` (Railway's own, 5,852 projects: prebuilt `ghcr.io/railwayapp-templates/chatwoot:Community` image, pgvector pg16, Valkey, local volume). Kept: pgvector Postgres, Redis-compatible store, `/api` health. Changed: official upstream image pinned, separate Sidekiq service, Bucket storage. Also reviewed `self-host-chatwoot` (web + Sidekiq with **separate** volumes, so Sidekiq cannot see uploads) and `chatwoot-1` (Amritasha repo, no license → nothing copied). |
| Upstream checked | Chatwoot `v4.18.0` (2026-09-18): `docker-compose.production.yaml`, `.env.example`, `config/storage.yml`, `config/database.yml`, `config/puma.rb`, `docker/Dockerfile`, `docker/entrypoints/rails.sh`, `db/schema.rb` (requires the `vector` extension), `app/models/installation_config.rb`, `lib/global_config_service.rb`, `lib/llm/config.rb`, `LICENSE` + `enterprise/LICENSE`. Pinned 2026-10-11. |

## Architecture

```
 agents + website visitors ──HTTPS──► chatwoot (Rails/Puma :3000: dashboard, API, widget, Action Cable)
                                         │  pre-deploy: rails db:chatwoot_prepare (+ optional Captain seed)
                ┌────────────────────────┼─────────────────────────┐
                ▼                        ▼                         ▼
     Postgres (pgvector, pg16)     Redis (queues, cable)     Railway Bucket (attachments, avatars)
                ▲                        ▲                         ▲
                └──────────── chatwoot-sidekiq (jobs: email, webhooks, channel sync, notifications, AI)
```

Railway volumes cannot be shared, and upstream's compose mounts one `storage_data` volume into both Rails and Sidekiq. Here both services use Active Storage's `s3_compatible` service on a Railway Bucket instead, so files uploaded through the dashboard are available to Sidekiq jobs (email attachments, channel uploads) and vice versa. Downloads are served through Rails redirects to short-lived signed URLs, so the bucket stays private.

## Services

| Service | Source | Start / pre-deploy | Public | Healthcheck | Volume | Restart | Replicas |
|---|---|---|---|---|---|---|---|
| `chatwoot` | repo `/services/chatwoot` (FROM `chatwoot/chatwoot:v4.18.0`) | pre-deploy `/app/railway/predeploy.sh`; start `/app/railway/web.sh` | domain → 3000 | `/api`, 300 s | — | ON_FAILURE ×10 | 1+ |
| `chatwoot-sidekiq` | same repo/root | start `/app/railway/sidekiq.sh` (waits for migrations, then `sidekiq -C config/sidekiq.yml`) | — | — | — | ON_FAILURE ×10 | 1+ |
| `Postgres` | image `pgvector/pgvector:0.8.7-pg16` with Railway-style variables from `_railway-base/postgres.json` | image | — | — | `/var/lib/postgresql/data` (`PGDATA=…/pgdata`) | ON_FAILURE ×10 | 1 |
| `Redis` | `redis:8.2` (from `_railway-base/redis.json`) | base start command | — | — | `/data` | ON_FAILURE ×10 | 1 |
| `Bucket` | Railway Bucket | — | — | — | — | — | — |

## Variables

**`chatwoot` (owner of shared values)**

| Variable | Default | Notes |
|---|---|---|
| `SECRET_KEY_BASE` | `${{secret(128, hex)}}` | Alphanumeric as upstream recommends. |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` / `_DETERMINISTIC_KEY` / `_KEY_DERIVATION_SALT` | `${{secret(32, alnum)}}` each | Required for MFA/2FA and encrypted columns. Never rotate. |
| `FRONTEND_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Update when adding a custom domain. |
| `MAILER_SENDER_EMAIL` | `Chatwoot <noreply@example.com>` | Set to a verified sender. |
| `POSTGRES_HOST` / `PORT` / `USERNAME` / `PASSWORD` / `DATABASE` | `${{Postgres.RAILWAY_PRIVATE_DOMAIN}}`, `5432`, `${{Postgres.PGUSER}}`, `${{Postgres.PGPASSWORD}}`, `${{Postgres.PGDATABASE}}` | Chatwoot's own variable names (see `config/database.yml`). |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` | |
| `ACTIVE_STORAGE_SERVICE` | `s3_compatible` | |
| `STORAGE_BUCKET_NAME`, `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`, `STORAGE_REGION`, `STORAGE_ENDPOINT` | `${{Bucket.BUCKET}}`, `${{Bucket.ACCESS_KEY_ID}}`, `${{Bucket.SECRET_ACCESS_KEY}}`, `${{Bucket.REGION}}`, `${{Bucket.ENDPOINT}}` | |
| `STORAGE_FORCE_PATH_STYLE` | `false` | New Railway Buckets use virtual-hosted URLs. |
| `PORT` | `3000` | |
| `RAILS_MAX_THREADS` / `WEB_CONCURRENCY` | `5` / `0` | Puma threads / worker processes. |
| `ENABLE_ACCOUNT_SIGNUP` | `false` | Read on first boot only (copied into the installation config); later change it in Super Admin → App Configs. |
| `FORCE_SSL` | `false` | TLS ends at Railway's edge. |
| `CAPTAIN_OPEN_AI_API_KEY` | *(empty, optional)* | If set, the pre-deploy step copies it (and `CAPTAIN_OPEN_AI_ENDPOINT` / `CAPTAIN_OPEN_AI_MODEL` if you add them) into Super Admin → App Configs → Captain, only while that setting is empty. |
| `LOG_LEVEL` | `info` | |

Baked into the image: `RAILS_ENV=production`, `NODE_ENV=production`, `INSTALLATION_ENV=docker`, `RAILS_LOG_TO_STDOUT=true`.

**`chatwoot-sidekiq`**: same database/Redis/storage variables; `SECRET_KEY_BASE`, the three encryption keys, `FRONTEND_URL` and `MAILER_SENDER_EMAIL` reference `${{chatwoot.*}}`; `SIDEKIQ_CONCURRENCY=10`; `RAILWAY_DEPLOYMENT_DRAINING_SECONDS=60`.

**Optional email (add to both services):** `SMTP_ADDRESS`, `SMTP_PORT` (587), `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_AUTHENTICATION` (`plain`/`login`), `SMTP_ENABLE_STARTTLS_AUTO=true`, `SMTP_DOMAIN`. Railway allows outbound SMTP only on the **Pro** plan; Chatwoot sends mail only via SMTP/sendmail, so on Trial/Hobby invitations, password resets, notification emails and email-channel replies cannot be delivered.

**Optional channels:** `FB_APP_ID`, `FB_APP_SECRET`, `FB_VERIFY_TOKEN`, `IG_VERIFY_TOKEN` (Facebook/Instagram), `SLACK_CLIENT_ID`, `SLACK_CLIENT_SECRET`, `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `AZURE_APP_ID`, `AZURE_APP_SECRET` (Gmail/Outlook email channels). WhatsApp Cloud API inboxes are configured in the dashboard with your Meta app credentials and need no server variables.

**Postgres (pgvector)**: Railway base variables (`PGDATA=/var/lib/postgresql/data/pgdata`, `POSTGRES_DB=railway`, `POSTGRES_USER=postgres`, `POSTGRES_PASSWORD=${{secret(32)}}`, `PG*` aliases, `DATABASE_URL`, draining 60 s) on the `pgvector/pgvector:0.8.7-pg16` image (no SSL; private network only).

## First start and accounts

1. The `chatwoot` pre-deploy step runs `db:chatwoot_prepare` (schema load + seed on an empty database, migrations afterwards). `chatwoot-sidekiq` waits until no migrations are pending.
2. Open the public domain. On a fresh install Chatwoot shows its **installation onboarding** form: the first person to submit it becomes the **Super Admin** and owner of the first account. Do this immediately after deploy (the generated `*.up.railway.app` domain is not published anywhere).
3. Public sign-up stays off (`ENABLE_ACCOUNT_SIGNUP=false`); add agents by invitation or from Super Admin (`/super_admin`).

## AI features

- **OpenAI integration** (reply suggestions, summaries, tone changes): account-level integration under Settings → Integrations → OpenAI, using your own API key. Part of the MIT-licensed core.
- **Captain AI** (AI agent, knowledge-base answers with pgvector embeddings): implemented in Chatwoot's `enterprise/` directory, which is under the Chatwoot Enterprise License — production use requires a Chatwoot subscription. The database is pgvector-ready and `CAPTAIN_OPEN_AI_API_KEY` can be seeded, but licensing is the operator's responsibility. Use the `v4.18.0-ce` image tag for an MIT-only build without Captain.

## Composer steps (Railway dashboard)

1. Add `Redis` from `_railway-base/redis.json`; add a Postgres service from `_railway-base/postgres.json` but change the image to `pgvector/pgvector:0.8.7-pg16` and drop `SSL_CERT_DAYS`; add a Bucket named `Bucket`.
2. `chatwoot`: GitHub repo `baranberkay96/chatwoot-railway`, root `/services/chatwoot`; pre-deploy command `/app/railway/predeploy.sh`; start command `/app/railway/web.sh`; healthcheck `/api` (300 s); domain → 3000; variables.
3. `chatwoot-sidekiq`: same repo/root; start command `/app/railway/sidekiq.sh`; variables with `${{chatwoot.*}}` references; no domain.

## Improvements over market templates

| Area | Market templates | This template |
|---|---|---|
| Image | Railway's prebuilt `chatwoot:Community` (version not visible) / `chatwoot/chatwoot:latest` | Official `chatwoot/chatwoot:v4.18.0`, one `FROM` line for both services |
| Processes | `chatwoot` / `chatwoot-1`: Sidekiq inside the web container | Separate `chatwoot-sidekiq` service, independently scalable, warm shutdown window |
| File storage | Local volume; `self-host-chatwoot` gives web and Sidekiq **different** volumes | Railway Bucket via `s3_compatible`, shared by all replicas; web and Sidekiq are stateless and scalable |
| Migrations | Run inside the start script or not at all | Railway pre-deploy (`db:chatwoot_prepare`) before every release; Sidekiq waits for the schema |
| Secrets | `chatwoot-1`: `SECRET_KEY_BASE` left empty for the user; market leader lacks Active Record encryption keys (MFA) | All secrets generated; encryption keys included and shared by reference |
| Postgres | `pgvector/pgvector:pg16` floating tag | `pgvector/pgvector:0.8.7-pg16` pinned with Railway-style variables and `PGDATA` sub-directory |
| Captain | Not addressed | pgvector-ready, optional key seeding without overwriting UI changes, licensing note |
| Email | SMTP variables without plan caveat | Documents the Pro-plan SMTP requirement |

## Resource profile and cost (Railway: RAM $10/GB-mo, vCPU $20/mo, volume $0.15/GB-mo, bucket $0.015/GB-mo)

| Service | Idle RAM | Typical RAM | Idle CPU | Typical CPU |
|---|---|---|---|---|
| chatwoot (Puma, 5 threads) | 0.55 GB | 0.8–1.2 GB | 0.02 | 0.1–0.4 |
| chatwoot-sidekiq (10 threads) | 0.45 GB | 0.6–1.0 GB | 0.03 | 0.1–0.3 |
| Postgres (pgvector) | 0.1 GB | 0.2–0.4 GB | 0.01 | 0.05–0.2 |
| Redis | 0.02 GB | 0.05–0.1 GB | 0 | 0.02 |
| **Total** | **~1.1 GB** | **~1.7–2.7 GB** | **~0.06 vCPU** | **~0.3–0.9 vCPU** |

Estimated monthly cost: **idle ≈ $13** (1.1 GB × $10 + 0.06 vCPU × $20 + ~1.5 GB volumes); **typical support team (5–20 agents, a few thousand conversations/month) ≈ $25–45**; each extra web or Sidekiq replica ≈ +$6–12. Bucket storage is cents per GB. Minimum plan: **Hobby** (Pro if you need outbound SMTP email).

## Scaling

- More agents / widget traffic: raise `chatwoot` replicas or `WEB_CONCURRENCY` (each Puma worker ≈ +0.4 GB).
- Busy channels, webhooks, AI jobs: raise `chatwoot-sidekiq` replicas or `SIDEKIQ_CONCURRENCY` (keep Postgres `max_connections` in mind: replicas × concurrency).
- Both services are stateless thanks to Bucket storage.

## Pinning and upgrades

Pinned 2026-10-11: `chatwoot/chatwoot:v4.18.0` (`services/chatwoot/Dockerfile`), `pgvector/pgvector:0.8.7-pg16`, `redis:8.2`. Upgrade: read the Chatwoot release notes, change the `FROM` tag, push. The pre-deploy step migrates before the new web release goes live; Sidekiq waits for the new schema.

## Verification checklist

- [ ] `chatwoot` deploy logs show the pre-deploy step (`db:chatwoot_prepare`) finishing, then `/api` returns JSON with `queue_services: ok` and `data_services: ok`.
- [ ] `chatwoot-sidekiq` logs: "waiting for database migrations" (first deploy only), then Sidekiq starts and processes the cron jobs.
- [ ] Complete the onboarding form; log in as Super Admin; `/super_admin` loads.
- [ ] Create a Website inbox, embed the widget on a test page, send a message with an image attachment → appears in the dashboard; the file is visible in the Bucket's file browser and loads in the conversation.
- [ ] Reply with an attachment from the dashboard → visitor receives it (Sidekiq processed the job using the shared Bucket file).
- [ ] Enable 2FA for your user (verifies the Active Record encryption keys).
- [ ] Redeploy all services: conversations, attachments and settings persist.
- [ ] Optional: with `CAPTAIN_OPEN_AI_API_KEY` set, Super Admin → App Configs → Captain shows the key after deploy.

## Open questions

- Not deployed end-to-end here. To confirm on first deploy: `aws-sdk-s3` with Railway's `REGION` value (`auto`) and virtual-hosted URLs, and the onboarding flow on an empty `railway` database.
- Listing copy mentions email: inbound email via IMAP works on every plan, but outbound email (SMTP) requires Railway Pro. Copy kept; caveat documented here and in the README.
- "AI assist" is delivered by the core OpenAI integration; Captain AI additionally requires a Chatwoot Enterprise licence for production use.
- PostgreSQL 16 (matching upstream's compose) instead of the Railway base 18, to stay on the version Chatwoot ships with.
