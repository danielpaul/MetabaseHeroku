# Pin if you want, e.g. v0.49.17. `latest` works too.
ARG METABASE_VERSION=latest
FROM --platform=linux/amd64 metabase/metabase:${METABASE_VERSION}

# Our wrapper becomes the only entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# No CMD; the entrypoint will exec Metabase
