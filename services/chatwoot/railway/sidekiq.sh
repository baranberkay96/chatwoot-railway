#!/bin/sh
# Chatwoot Sidekiq worker. Railway starts all services together, so on the
# first deploy wait (bounded) until the web service's pre-deploy step has
# migrated the database.
set -eu
cd /app

tries="${MIGRATION_WAIT_TRIES:-60}"
i=1
until bundle exec rails db:abort_if_pending_migrations >/dev/null 2>&1; do
  if [ "${i}" -ge "${tries}" ]; then
    echo "[railway] FATAL: database not migrated after ${tries} checks; see the chatwoot pre-deploy logs" >&2
    exit 1
  fi
  echo "[railway] waiting for database migrations (${i}/${tries})"
  i=$((i + 1))
  sleep 10
done

exec bundle exec sidekiq -C config/sidekiq.yml
