# Metabase on Heroku (via `heroku.yml`) — **Updated**

Production-ready Metabase on Heroku using Docker **and** a tiny wrapper entrypoint. This repo:

* Builds on Heroku’s x86\_64 builders (no Apple-Silicon/ARM issues)
* Maps `DATABASE_URL` → `MB_DB_CONNECTION_URI` at runtime
* Binds to Heroku’s `$PORT`
* Caps JVM memory to avoid **R15 (Memory quota exceeded)** on small dynos
* Provisions **Heroku Postgres** automatically at app creation

---

## Repo layout

```
.
├─ Dockerfile
├─ docker-entrypoint.sh
├─ heroku.yml
├─ .dockerignore
└─ README.md
```

* **Dockerfile** – wraps the official Metabase image and installs our entrypoint
* **docker-entrypoint.sh** – sets env (port/host, DB URI) then execs Metabase
* **heroku.yml** – builds the image on Heroku and provisions Postgres + baseline config
* **.dockerignore** – keeps the image lean

---

## Files

### `heroku.yml`

```yaml
setup:
  addons:
    - plan: heroku-postgresql:essential-0   # creates DATABASE_URL for Metabase app DB
  config:
    # JVM & server tuning for 512–1GB dynos (prevents R15 OOM on boot)
    JAVA_TOOL_OPTIONS: -Xms256m -Xmx384m -XX:MaxMetaspaceSize=128m -XX:+UseSerialGC -XX:+ExitOnOutOfMemoryError
    MB_JETTY_MAXTHREADS: "50"

build:
  docker:
    web: Dockerfile
```

> `setup:` only runs **when the app is created** (via `--manifest`).

### `Dockerfile`

```dockerfile
ARG METABASE_VERSION=latest
FROM metabase/metabase:${METABASE_VERSION}

# Our wrapper entrypoint replaces the image entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
```

### `docker-entrypoint.sh`

```sh
#!/bin/sh
set -e

# Map Heroku's DATABASE_URL to what Metabase expects (unless already set)
if [ -z "$MB_DB_CONNECTION_URI" ] && [ -n "$DATABASE_URL" ]; then
  export MB_DB_CONNECTION_URI="$DATABASE_URL"
fi

# Bind correctly on Heroku
export MB_JETTY_HOST="${MB_JETTY_HOST:-0.0.0.0}"
export MB_JETTY_PORT="${PORT:-3000}"

# Hand off to Metabase's normal startup
exec /app/run_metabase.sh
```

### `.dockerignore`

```
.git
.gitignore
README.md
```

---

## One-time app creation (provisions Postgres)

```bash
APP=<your-app-name>

# Create the app from the manifest (uses heroku.yml -> setup.addons + config)
heroku apps:create $APP --stack container --manifest

# Required secrets (cannot be generated in heroku.yml)
heroku config:set -a $APP \
  MB_ENCRYPTION_SECRET_KEY="$(openssl rand -hex 32)" \
  MB_SITE_URL="https://$APP.herokuapp.com"
```

---

## Deploy

Use Heroku Git or connect GitHub and enable automatic deploys.

```bash
heroku git:remote -a $APP
git add .
git commit -m "Initial Metabase on Heroku"
git push heroku main

# watch it boot
heroku logs -t -a $APP
```

---

## Memory sizing tips

This README pins conservative defaults for small dynos:

```bash
JAVA_TOOL_OPTIONS='-Xms256m -Xmx384m -XX:MaxMetaspaceSize=128m -XX:+UseSerialGC -XX:+ExitOnOutOfMemoryError'
MB_JETTY_MAXTHREADS=50
```

* If you still see **R15** on a 512 MB dyno, try `-Xmx320m`, or upgrade:

  ```bash
  heroku ps:type web=standard-2x -a $APP   # 1 GB
  ```
* For larger dynos, raise `-Xmx` to \~60–75% of plan memory.

---

## Connect your data sources

After boot:

1. Visit the app and complete the setup wizard.
2. **Admin → Databases → Add database**.
3. For other Heroku Postgres DBs, copy that app’s `DATABASE_URL` and use it (ensure `sslmode=require` for Postgres).
4. For external DBs (RDS, Cloud SQL, on-prem), enable SSL and allow Heroku egress IPs as needed.

> The *Metabase application database* (where Metabase stores users/dashboards) is the Postgres add-on created by `setup.addons`. Your **data sources** are added separately in the UI.

---

## Upgrading Metabase

Edit `Dockerfile`:

```dockerfile
ARG METABASE_VERSION=v0.49.17
FROM metabase/metabase:${METABASE_VERSION}
```

Commit & deploy.

---

## Local test (optional)

```bash
# Start a local Postgres
docker run -d --name mb-pg -e POSTGRES_PASSWORD=pass -e POSTGRES_USER=mb -e POSTGRES_DB=metabase -p 5433:5432 postgres:16

# Build & run Metabase locally
docker build -t mb-heroku .
docker run --rm -p 3000:3000 \
  -e DATABASE_URL="postgres://mb:pass@host.docker.internal:5433/metabase?sslmode=disable" \
  -e MB_ENCRYPTION_SECRET_KEY="$(openssl rand -hex 32)" \
  mb-heroku

# Open http://localhost:3000
```

---

## Troubleshooting

* **R15 / exit 137**: lower `-Xmx` or use a bigger dyno.
* **H10 / 503**: usually a crash loop from OOM; check `heroku logs -t`.
* **“Unrecognized command: '/bin/sh' or '/app/run\_metabase.sh'”**: means Heroku passed your command as args to Metabase. This repo avoids it by replacing the image entrypoint—ensure you’re not adding a Procfile or `run:` in `heroku.yml`.
* **App DB migrations failing**: confirm `MB_DB_CONNECTION_URI` is set (our entrypoint maps it automatically from `DATABASE_URL`).

---

## Security notes

* Keep `MB_ENCRYPTION_SECRET_KEY` stable and secret (it encrypts saved credentials).
* Restrict admin access; consider SSO configuration.
* Dyno filesystem is ephemeral—don’t rely on local files.

