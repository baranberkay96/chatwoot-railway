# Deploy and Host Chatwoot with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/chatwoot-v4-omnichannel-support-desk)

Chatwoot is an open-source customer support platform that brings website live chat, email, WhatsApp, Facebook, Instagram, Telegram and other channels into one shared team inbox. This community template runs Chatwoot v4 on Railway with a separate Sidekiq worker, PostgreSQL with pgvector, Redis and a Railway Bucket for attachments.

## About Hosting Chatwoot

Chatwoot is a Rails application with two processes: the web server (dashboard, REST API, website widget and real-time updates over Action Cable) and Sidekiq, which runs background jobs such as sending emails, syncing channels, delivering webhooks and AI tasks. Both need PostgreSQL (with the pgvector extension, which Chatwoot's schema requires) and Redis. Because Railway volumes belong to a single service, this template stores attachments and avatars in a Railway Bucket through Active Storage, so the web server and every Sidekiq replica see the same files. Database migrations run in a Railway pre-deploy step before each release, all secrets are generated, and the first visitor completes Chatwoot's installation onboarding to become Super Admin.

## Common Use Cases

- Website live chat and help center for SaaS and e-commerce support teams.
- One shared inbox for WhatsApp Cloud API, email, Facebook, Instagram and Telegram conversations.
- Self-hosted alternative to Intercom or Zendesk with data kept in your own infrastructure.
- AI-assisted replies and conversation summaries with your own OpenAI key.
- Agencies running separate accounts for several clients on one installation.

## Dependencies for Chatwoot Hosting

- Chatwoot (`chatwoot/chatwoot`) web and Sidekiq processes
- PostgreSQL 16 with pgvector
- Redis
- S3-compatible object storage (Railway Bucket)
- Optional: SMTP server for outgoing email (Railway Pro plan), channel app credentials (Meta, Google, Microsoft, Slack)

### Deployment Dependencies

- Chatwoot self-hosting documentation: https://www.chatwoot.com/docs/self-hosted
- Environment variables reference: https://www.chatwoot.com/docs/self-hosted/configuration/environment-variables
- Docker deployment guide: https://www.chatwoot.com/docs/self-hosted/deployment/docker
- Chatwoot releases: https://github.com/chatwoot/chatwoot/releases
- pgvector: https://github.com/pgvector/pgvector
- Railway outbound email: https://docs.railway.com/networking/outbound-networking

### Implementation Details

| Service | Image | Role | Public |
|---|---|---|---|
| `chatwoot` | `chatwoot/chatwoot:v4.18.0` + launch scripts | Dashboard, API, widget, Action Cable; runs migrations in pre-deploy | HTTPS domain |
| `chatwoot-sidekiq` | same image | Background jobs | — |
| `Postgres` | `pgvector/pgvector:0.8.7-pg16` | Database | — |
| `Redis` | `redis:8.2` | Queues, real-time, cache | — |
| `Bucket` | Railway Bucket | Attachments and avatars | — |

**First login.** When `chatwoot` is healthy, open its domain right away and complete the onboarding form; that user becomes Super Admin. Public sign-up is off; invite agents from Settings → Agents.

**Email.** Add `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` and `MAILER_SENDER_EMAIL` to both Chatwoot services. Railway only allows outbound SMTP on the Pro plan, so on Hobby email notifications and email-channel replies are not delivered.

**AI.** Connect OpenAI per account under Settings → Integrations. Captain AI (Chatwoot's AI agent) is part of Chatwoot's enterprise edition and needs a Chatwoot licence for production use; set `CAPTAIN_OPEN_AI_API_KEY` to pre-fill its key.

**Scaling.** Web and Sidekiq are stateless: add replicas to `chatwoot` for more agents and widget traffic, and to `chatwoot-sidekiq` for busier channels and webhooks.

**Pinning and upgrades.** The Chatwoot version is the `FROM` line in `services/chatwoot/Dockerfile`. Change it after reading the release notes and push; migrations run before the new version goes live.

### Why Deploy Chatwoot on Railway?

Railway runs Chatwoot, its worker, database, Redis and object storage together on a private network with automatic HTTPS. You can scale web and worker capacity independently and keep customer conversations in infrastructure you control, with usage-based pricing instead of per-agent seats.
