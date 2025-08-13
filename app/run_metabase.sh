#!/usr/bin/env bash

if [ "$DATABASE_URL" ]; then
  export MB_DB_CONNECTION_URI="$DATABASE_URL"
fi

if [ "$PORT" ]; then
  export MB_JETTY_PORT="$PORT"
fi
