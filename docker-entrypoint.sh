#!/bin/sh
set -e

# Use Heroku's DATABASE_URL unless MB_DB_CONNECTION_URI is explicitly set
if [ -z "$MB_DB_CONNECTION_URI" ] && [ -n "$DATABASE_URL" ]; then
  export MB_DB_CONNECTION_URI="$DATABASE_URL"
fi

# Bind correctly on Heroku
export MB_JETTY_HOST="${MB_JETTY_HOST:-0.0.0.0}"
export MB_JETTY_PORT="${PORT:-3000}"

# Hand off to Metabase's normal startup
exec /app/run_metabase.sh
