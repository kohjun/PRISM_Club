# PRISM Club — Staging Environment Setup

Step-by-step guide to standing up a **staging** environment for Beta.
Staging is the rehearsal venue: the same image, schema, and config
shape as production, but pointed at a non-production database with
non-production secrets. It exists so the engineer running cut-over
can rehearse [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) end to
end before doing it for real.

> **Do NOT deploy production from this guide.** Production cut-over
> uses [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md). This file is
> the rehearsal preparation only.

Pairs with:

- [HANDOFF.md](HANDOFF.md) — entry point for new engineers
- [DEPLOYMENT.md](DEPLOYMENT.md) — env matrix + container build
- [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) — execution-time guide
- [STAGING_SMOKE.md](STAGING_SMOKE.md) — how to smoke against the staging host
- [.env.staging.example](../.env.staging.example) — staging-shaped env template
- [docker-compose.staging.example.yml](../docker-compose.staging.example.yml) — runtime template for a single-VM staging host

---

## 1. Required services

A staging install needs exactly five things plus DNS. Reuse organization-
standard tooling — none of these are project-specific.

| # | Service | What it does | Minimum spec |
|---|---|---|---|
| 1 | **Postgres 16** | Application DB + `prisma_club_test` for backend e2e (optional) | `db.t4g.medium` / 2 vCPU / 4 GB / 10 GB storage / single-AZ |
| 2 | **API host (container)** | Runs `apps/api` (NestJS) | 1 vCPU / 1 GB / 1 replica is enough at staging |
| 3 | **Flutter web static host** | Serves `apps/mobile/build/web` | Any HTTP static host (S3+CloudFront, Cloudflare Pages, nginx) |
| 4 | **Admin web static host** | Serves `apps/admin/dist` | Any HTTP static host (separate origin from #3) |
| 5 | **Media storage** | Either filesystem volume (staging-only acceptable) OR S3-compatible bucket | 1 GB to start; S3 strongly recommended before sharing the URL |
| (6) | **PRISM EVENT upstream** | Real CONTENIDO / PRISM EVENT API endpoint | Only needed when `EVENTS_CLIENT_MODE=prism`. Acceptable to start in `mock` mode and flip later (see §8). |

Pre-launch DNS:

- `https://api.staging.<your-domain>` → API host
- `https://app.staging.<your-domain>` → Flutter web bundle
- `https://admin.staging.<your-domain>` → Admin web bundle

TLS terminates at the load balancer / reverse proxy. The API does NOT
serve HTTPS itself.

---

## 2. Staging environment variable checklist

Use the placeholder file [`.env.staging.example`](../.env.staging.example)
as the template. Copy to your secret store, fill in real values, **never
commit the real file**.

The full env matrix lives in [DEPLOYMENT.md](DEPLOYMENT.md) §2. Staging
values:

| Variable | Staging value | Notes |
|---|---|---|
| `DATABASE_URL` | Managed Postgres URI (e.g. `postgresql://prism_staging:<pw>@<host>:5432/prism_club_staging?schema=public`) | Use a dedicated staging DB user, not the prod one. |
| `API_PORT` | Whatever your platform binds (e.g. `8080` on Cloud Run) | If unset, defaults to `3000`. |
| `NODE_ENV` | `production` | Yes, even on staging. Otherwise the legacy `X-User-Id` fallback is silently allowed. |
| `JWT_SECRET` | Fresh `openssl rand -hex 32` value, **distinct** from production | Never reuse prod's secret on staging. |
| `ALLOW_X_USER_ID` | `1` (acceptable for staging only) | Lets `scripts/smoke.sh` work without the JWT flow. Production MUST leave this unset. |
| `CORS_ORIGINS` | `https://app.staging.<your-domain>,https://admin.staging.<your-domain>` | Comma-separated. No `*`. |
| `EVENTS_CLIENT_MODE` | `mock` for first boot; flip to `prism` once upstream creds are ready (see §8) | Falls back to mock if `prism` is set without `PRISM_EVENTS_API_BASE_URL`. |
| `PRISM_EVENTS_API_BASE_URL` | empty for first boot | Set when flipping mode. |
| `PRISM_EVENTS_API_KEY` | empty for first boot | Set when flipping mode. |
| `PRISM_EVENTS_TIMEOUT_MS` | `4000` | Tune later if upstream is slow. |
| `MEDIA_STORAGE_MODE` | `local` for first smoke; switch to `s3` before external testers (see §9) | Local mode does not survive container restart / horizontal scale. |
| `UPLOADS_DIR` | `/app/uploads` (image default) | Used only when `MEDIA_STORAGE_MODE=local`. Mount a volume here. |
| `MEDIA_PUBLIC_BASE_URL` | empty (local) OR `https://<cdn-or-bucket>` (s3) | Required for s3 mode. |
| `S3_BUCKET` / `S3_REGION` / `S3_ACCESS_KEY_ID` / `S3_SECRET_ACCESS_KEY` | bucket creds for s3 mode | Mint a staging-only IAM key. |
| `S3_ENDPOINT` | only for R2 / MinIO | AWS default used otherwise. |
| `S3_OBJECT_PREFIX` | `staging-uploads` (recommended) | Keep staging objects partitioned from production if you share a bucket — but a separate bucket is safer. |
| `S3_FORCE_PATH_STYLE` | `1` for MinIO | otherwise unset. |
| `NOTIFICATION_DELIVERY_MODE` | `noop` | The `email` / `push` boundaries are stubs at Beta. Do not flip. |
| `EMAIL_*` / `PUSH_*` | empty | Reserved for post-Beta. |

**Plain env vs. secret store:**

- Plain env (any platform variable, log-visible OK):
  `API_PORT`, `NODE_ENV`, `ALLOW_X_USER_ID`, `CORS_ORIGINS`,
  `EVENTS_CLIENT_MODE`, `PRISM_EVENTS_API_BASE_URL`,
  `PRISM_EVENTS_TIMEOUT_MS`, `MEDIA_STORAGE_MODE`,
  `MEDIA_PUBLIC_BASE_URL`, `UPLOADS_DIR`, `S3_BUCKET`, `S3_REGION`,
  `S3_ENDPOINT`, `S3_OBJECT_PREFIX`, `S3_FORCE_PATH_STYLE`,
  `NOTIFICATION_DELIVERY_MODE`.
- Secret store (NEVER plain env, NEVER logs, NEVER commits):
  `DATABASE_URL`, `JWT_SECRET`, `PRISM_EVENTS_API_KEY`,
  `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, future `EMAIL_API_KEY`,
  future `PUSH_SERVICE_ACCOUNT`.

---

## 3. Secret generation checklist

Generate fresh, staging-only values before touching anything.

```bash
# JWT signing secret (32 random bytes hex-encoded)
openssl rand -hex 32
# → paste into the secret store as JWT_SECRET

# Database password (avoid shell special characters that would need
# URL-encoding inside DATABASE_URL):
openssl rand -base64 24 | tr '+/' '-_' | head -c 32
# → use as the password for the prism_staging DB user

# S3 access key / secret: mint via the cloud console (AWS IAM /
# Cloudflare R2 token / MinIO admin). Scope to s3:PutObject +
# s3:GetObject on the staging bucket ONLY.
```

Confirm before launch:

- [ ] `JWT_SECRET` is fresh and is NOT the production secret.
- [ ] `DATABASE_URL` points at a dedicated staging DB user that owns
      a dedicated staging database. The user does NOT have access to
      production data.
- [ ] If `MEDIA_STORAGE_MODE=s3`: the IAM key is scoped to the
      staging bucket only.
- [ ] If `EVENTS_CLIENT_MODE=prism`: the `PRISM_EVENTS_API_KEY`
      identifies a staging client, not a production one.
- [ ] No real value from §2 appears in `git log -p`, the terminal
      history, or chat scrollback.

---

## 4. Database creation + migration checklist

### 4.1 Create the staging database

On a fresh Postgres instance:

```sql
-- Run as the Postgres superuser:
CREATE ROLE prism_staging WITH LOGIN PASSWORD '<staging-password>';
CREATE DATABASE prism_club_staging OWNER prism_staging;
\c prism_club_staging
GRANT ALL PRIVILEGES ON SCHEMA public TO prism_staging;
```

If your managed Postgres provider already provisioned a user + DB, skip
the `CREATE ROLE` step and use what the provider gave you.

### 4.2 Apply migrations

From a workstation that can reach the staging DB (NOT from inside the
API container — `prisma migrate deploy` runs as a one-shot job, not on
boot):

```bash
DATABASE_URL="<staging-database-url>" npx prisma migrate deploy
```

Expected output ends with `All migrations have been successfully applied`
(or `No pending migrations to apply.` on subsequent runs).

Verify:

```bash
DATABASE_URL="<staging-database-url>" npx prisma migrate status
# → "Database schema is up to date!"
```

### 4.3 Bootstrap a CURATOR / MODERATOR / ADMIN account

The seed personas are dev-only. Create at least one operations account
manually:

```sql
\c prism_club_staging
INSERT INTO users (id, status) VALUES (gen_random_uuid(), 'ACTIVE')
  RETURNING id;
-- Save the returned UUID as <admin-uuid>.

INSERT INTO profiles (user_id, nickname)
  VALUES ('<admin-uuid>', 'staging_admin');

INSERT INTO user_roles (id, user_id, role, source)
  VALUES (gen_random_uuid(), '<admin-uuid>', 'ADMIN', 'staging-bootstrap');
```

Record `<admin-uuid>` in your ops vault — it's how you log into the
admin web during the staging rehearsal.

### 4.4 (Optional) Seed test data

Staging does NOT auto-seed. If you want the six demo personas + topic
hubs + posts that the dev environment has, run the seed script against
the staging DB once:

```bash
DATABASE_URL="<staging-database-url>" npm run db:seed
```

Be aware: this creates the personas with **well-known fixed UUIDs**
(`11111111-1111-1111-1111-111111111111`, etc.). If staging is reachable
from the public internet, anyone who reads this repo can log in as those
personas. Either skip the seed entirely, or block public access to the
staging API by IP allowlist.

---

## 5. Flutter web build config

```bash
cd apps/mobile
flutter pub get
flutter build web --no-tree-shake-icons \
  --dart-define=API_BASE_URL=https://api.staging.<your-domain>/v1
```

The compiled bundle lives in `apps/mobile/build/web`. Upload it to the
static host serving `https://app.staging.<your-domain>`.

Compile-time defines:

| Define | Staging value | Notes |
|---|---|---|
| `API_BASE_URL` | `https://api.staging.<your-domain>/v1` | Must end with `/v1`. Without the override, the bundle defaults to `localhost:3000/v1`. |

`apiBaseUrl` resolution lives at `apps/mobile/lib/core/config.dart`.

---

## 6. Admin web build config

```bash
cd apps/admin
npm install
VITE_API_BASE_URL=https://api.staging.<your-domain>/v1 npm run build
```

The compiled bundle lives in `apps/admin/dist`. Upload it to the static
host serving `https://admin.staging.<your-domain>`.

The admin app reads `VITE_API_BASE_URL` at build time and writes it as
the default for the login form's "API base URL" input. The user can
still override it at runtime, so the build value is a sane default, not
a hard constraint.

The admin app authenticates via `POST /v1/auth/login` and persists the
JWT in localStorage. It is role-gated client-side (CURATOR / MODERATOR
/ ADMIN) AND server-side — you cannot bypass either gate by modifying
the SPA.

---

## 7. Health check URLs

Wire your load balancer and monitoring against:

| URL | Purpose | Expected response |
|---|---|---|
| `https://api.staging.<your-domain>/v1/health` | Liveness — is the process up? | `200 {"ok": true}` |
| `https://api.staging.<your-domain>/v1/health/ready` | Readiness — is Postgres reachable? | `200 {"ok": true, "db": "up"}` (503 with error body when DB is unreachable) |

Wiring details live in [DEPLOYMENT.md](DEPLOYMENT.md) §6. At staging:

- LB health check → `/v1/health/ready` every 10s.
- Optional uptime monitor → `/v1/health` every 60s.

---

## 8. PRISM EVENT integration mode

> **First staging boot: `EVENTS_CLIENT_MODE=mock`.** The mock client
> serves the bundled fixture, so the Topic Hub / Event Detail / search
> surfaces have data without any upstream dependency. This is the
> recommended starting point — it removes one integration variable
> while you stabilize the rest.

> **Flip to `prism` only after** the staging credentials for the real
> PRISM EVENT / CONTENIDO endpoint are available. The boundary will
> log a warning and fall back to mock if `EVENTS_CLIENT_MODE=prism` is
> set without `PRISM_EVENTS_API_BASE_URL` — so a misconfigured prism
> mode does not break the rest of staging, but it does mean you are
> not actually exercising the upstream until both envs are set.

Flip procedure:

1. Confirm the upstream team is ready for staging traffic (URL +
   API key + agreed rate limit).
2. Set both `EVENTS_CLIENT_MODE=prism` and `PRISM_EVENTS_API_BASE_URL=...`
   (and `PRISM_EVENTS_API_KEY` if required) in the staging secret store.
3. Roll the API pods so the new env takes effect.
4. Verify with `curl -H "Authorization: Bearer <admin-jwt>"
   https://api.staging.<your-domain>/v1/admin/events-client/status` —
   expect `mode: "prism"`, `base_url_configured: true`, all stats zero.
5. Run a search via Flutter web or curl. Re-check the diagnostic —
   `parsed_ok` should be > 0, `parse_failed` should be 0.

Full contract + failure matrix: [EVENTS_INTEGRATION.md](EVENTS_INTEGRATION.md).

---

## 9. Media storage mode

> **First staging smoke: `MEDIA_STORAGE_MODE=local` is acceptable.**
> Mount a volume at `/app/uploads` and the API will serve uploads from
> `/uploads/<id>.<ext>`. Good enough for a first-boot smoke where you
> just want to confirm the upload code path works end to end without
> wiring S3 credentials.

> **Before sharing the staging URL with external testers, switch to
> `MEDIA_STORAGE_MODE=s3`.** Local mode does NOT survive container
> restarts and does NOT scale horizontally — testers will see broken
> images the moment a pod recycles.

Flip procedure:

1. Provision an S3-compatible bucket (AWS S3, Cloudflare R2, or MinIO)
   and an IAM key scoped to `s3:PutObject` + `s3:GetObject` on the
   staging bucket only.
2. Set `MEDIA_STORAGE_MODE=s3`, `S3_BUCKET`, `S3_REGION`,
   `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`,
   `MEDIA_PUBLIC_BASE_URL=https://<cdn-or-bucket-host>`. Add
   `S3_ENDPOINT` + `S3_FORCE_PATH_STYLE=1` for R2 / MinIO.
3. Roll the API pods.
4. Upload a test image. Confirm the response `url` points at
   `<MEDIA_PUBLIC_BASE_URL>/<S3_OBJECT_PREFIX>/<uuid>.<ext>` and that
   the URL is fetchable in a browser.

S3MediaStorage validates configuration **lazily** — the API will boot
fine even if S3 envs are wrong, but the first upload will fail with a
500. Test the upload path before sharing the URL.

Existing local uploads are NOT migrated automatically. If staging has
been collecting `/uploads/*` files locally, plan to either delete them
or copy them into the bucket before the cut-over.

---

## 10. Smoke test against staging

Once everything above is configured and the API pod is running:

```bash
API=https://api.staging.<your-domain>/v1 bash scripts/smoke.sh
```

`scripts/smoke.sh` uses the legacy `X-User-Id` header, which only works
when `ALLOW_X_USER_ID=1`. Per §2, staging keeps this enabled, so smoke
works directly. Production MUST leave it unset and rely on the QA
script + headless verification suite instead.

Detailed smoke procedure (prereqs, token minting, interpreting
failures, cleanup): [STAGING_SMOKE.md](STAGING_SMOKE.md).

---

## 11. Rollback notes

Staging exists so you can rehearse the production runbook safely. The
rollback paths from [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) §7
all apply on staging — practice them.

Staging-specific safety net: because staging carries no real user data,
you have an additional rollback path that production does NOT have:

```bash
# Wipe + reapply migrations + reseed:
DATABASE_URL="<staging-database-url>" npx prisma migrate reset --force
# Re-bootstrap the ops account per §4.3 afterwards.
```

`prisma migrate reset --force` drops the schema and reapplies every
migration from scratch. Use it only on staging — running it against
production destroys data.

Most useful checks when staging breaks:

- `curl https://api.staging.<your-domain>/v1/health/ready` — is the API
  alive and reaching the DB?
- `curl -H "Authorization: Bearer <admin-jwt>"
  https://api.staging.<your-domain>/v1/admin/events-client/status` —
  is the upstream events client healthy?
- `kubectl logs <api-pod> --tail 100` (or platform equivalent) — what
  is the API actually saying?
- `DATABASE_URL=... npx prisma migrate status` — is the schema where
  the code expects it to be?

---

## 12. Single-VM runtime template

If you are running staging on a single VM (the simplest possible
deploy), `docker-compose.staging.example.yml` at the repo root is a
turn-key starting point. It defines:

- a Postgres 16 container with named-volume storage (NOT exposed to
  the host; can be swapped for a managed DB by removing the service
  and setting `DATABASE_URL` on the api service)
- the API container with full env wiring (env vars referenced through
  `${VAR}` / `${VAR:-default}` so the template carries no secrets)
- a persistent volume for `MEDIA_STORAGE_MODE=local` uploads
- a healthcheck against `GET /v1/health/ready` that marks the
  container `unhealthy` (without killing it) when the DB is unreachable
- an optional nginx static-host block (commented out) for serving the
  Flutter web + admin web bundles alongside the API

Usage:

```bash
# 1. Copy the template — DO NOT commit the populated copy.
cp docker-compose.staging.example.yml docker-compose.staging.yml

# 2. Populate required env vars in your shell or a sibling .env file
#    (POSTGRES_PASSWORD, JWT_SECRET, CORS_ORIGINS at minimum).
export POSTGRES_PASSWORD=<staging-db-password>
export JWT_SECRET=<staging-jwt-secret>
export CORS_ORIGINS=https://app.staging.<your-domain>,https://admin.staging.<your-domain>

# 3. Validate before bring-up.
docker compose -f docker-compose.staging.yml config

# 4. Build the API image locally (or pull from your registry).
docker build -t prism-club-api:staging -f apps/api/Dockerfile .

# 5. Bring it up.
docker compose -f docker-compose.staging.yml up -d

# 6. Apply migrations from the host (the container does NOT migrate
#    on boot — same as production).
DATABASE_URL="postgresql://prism_staging:$POSTGRES_PASSWORD@127.0.0.1:5432/prism_club_staging?schema=public" \
  npx prisma migrate deploy
```

> **Warnings.** This template is for a single-VM rehearsal staging:
> - It does NOT terminate TLS. Put a reverse proxy (nginx, Caddy,
>   Traefik, Cloud Load Balancer) in front of `127.0.0.1:3000` for
>   HTTPS.
> - It does NOT replace `docker-compose.yml`. The local dev compose
>   binds Postgres on host 5433 with default credentials — fine for
>   dev, never for staging.
> - It is intentionally placeholder-only. Never commit the populated
>   copy. `docker-compose.staging.yml` is gitignored by the existing
>   `**/build/` and platform-specific patterns; double-check before
>   pushing.
> - It does not assume any paid provider. Swap in managed Postgres
>   / S3 / CDN via env vars as your platform requires.

When staging needs HA, autoscaling, or zero-downtime deploys, graduate
to a Kubernetes / Cloud Run / ECS manifest. The env matrix
([DEPLOYMENT.md](DEPLOYMENT.md) §2) does not change; only the runtime
host does.

---

## 13. Pre-cut-over checklist

Treat this list as the "staging is ready" gate. None of these block
the rehearsal itself; missing any one of them means staging is not
representative of production yet.

- [ ] All five hosts from §1 reachable from the public internet (or
      whatever your testing surface needs).
- [ ] TLS valid on all three staging URLs (api / app / admin).
- [ ] §3 secrets all generated and stored. None in `.env`, none in
      `git log`.
- [ ] §4 migrations applied + ops account bootstrapped.
- [ ] §5 Flutter web bundle uploaded with the staging `API_BASE_URL`.
- [ ] §6 admin web bundle uploaded with the staging `VITE_API_BASE_URL`.
- [ ] §7 health endpoints return 200.
- [ ] §10 `scripts/smoke.sh` against the staging URL passes.
- [ ] One full pass of [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md) against
      the staging URL.
- [ ] `EVENTS_CLIENT_MODE` decision made (mock for first smoke, prism
      before external testers).
- [ ] `MEDIA_STORAGE_MODE` decision made (local for first smoke, s3
      before external testers).

When the box is checked: staging is ready for the production rehearsal.
Walk [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) against staging
once before scheduling the real cut-over window.
