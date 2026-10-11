#!/bin/sh
# Chatwoot web (Rails/Puma). Migrations already ran in the pre-deploy step.
set -eu
cd /app
rm -f /app/tmp/pids/server.pid
exec bundle exec rails s -p "${PORT:-3000}" -b 0.0.0.0
