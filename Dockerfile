# Pin if you want, e.g. v0.49.17. `latest` works too.
ARG METABASE_VERSION=latest
FROM metabase/metabase:${METABASE_VERSION}

# Heroku requires binding to 0.0.0.0 and $PORT
ENV MB_JETTY_HOST=0.0.0.0

# Heroku (container stack) runs the image's CMD; keep Metabase's entrypoint
# and provide a CMD that forwards to the standard startup script while
# injecting the Heroku port.
CMD ["/bin/sh","-lc","export MB_JETTY_PORT=${PORT:-3000}; exec /app/run_metabase.sh"]
