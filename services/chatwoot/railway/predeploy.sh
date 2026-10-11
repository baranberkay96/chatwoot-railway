#!/bin/sh
# Railway pre-deploy command for the Chatwoot web service.
# Runs before every deployment goes live:
#   1. db:chatwoot_prepare  - creates the database on first run, otherwise runs
#                             pending migrations (upstream's recommended task)
#   2. optional Captain seed - copies CAPTAIN_OPEN_AI_* variables into the
#                             installation config once (see seed_captain.rb)
set -eu
cd /app

echo "[railway] bundle exec rails db:chatwoot_prepare"
bundle exec rails db:chatwoot_prepare

if [ -n "${CAPTAIN_OPEN_AI_API_KEY:-}" ]; then
  echo "[railway] seeding Captain LLM settings"
  bundle exec rails runner /app/railway/seed_captain.rb
fi

echo "[railway] pre-deploy finished"
