# Chatwoot for Railway: official image + small launch scripts.
# Both Chatwoot services (web and Sidekiq) build from this file, so this FROM
# line is the single place that pins the Chatwoot version.
#
# Use chatwoot/chatwoot:v4.18.0-ce instead for the MIT-only Community Edition
# build (no enterprise/ code, therefore no Captain AI).
FROM chatwoot/chatwoot:v4.18.0

COPY --chmod=755 railway/ /app/railway/

ENV RAILS_ENV=production \
    NODE_ENV=production \
    INSTALLATION_ENV=docker \
    RAILS_LOG_TO_STDOUT=true

EXPOSE 3000

CMD ["/app/railway/web.sh"]
