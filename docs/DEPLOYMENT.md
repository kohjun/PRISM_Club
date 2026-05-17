# PRISM Club — Deployment Guide

This document covers what's needed to stand up an alpha environment of
PRISM Club. It does NOT describe a managed production deployment with HA
Postgres, S3-backed media, push notifications, or a CDN — those are tracked
in `NEXT_BACKLOG.md`. The goal here is: a single API container plus a
Flutter web build that you can put behind any reverse proxy.

---

## 1. Components

| Component | Where it lives | Notes |
|---|---|---|
| **API** | `apps/api` (NestJS, TypeScript) | Stateless except for `UPLOADS_DIR`. |
| **Database** | PostgreSQL 16 | Prisma migrations under `prisma/migrations`. |
| **Mobile / Web client** | `apps/mobile` (Flutter) | Web build is a static bundle. Native builds are out of scope here. |
| **Uploads directory** | Filesystem path | Local dev = `apps/api/uploads/`. Production should mount persistent storage. |

---

## 2. Environment matrix

The single source of truth is `.env.example`. Copy it to `.env` and adjust.

| Variable | Required | Dev default | Production guidance |
|---|---|---|---|
| `DATABASE_URL` | yes | `postgresql://prism:prism@localhost:5433/prism_club?schema=public` | Managed Postgres connection string. |
| `DATABASE_URL_TEST` | only for `test:e2e` | separate `prism_club_test` DB | Not used in production. |
| `API_PORT` | no | `3000` | Set to the port your platform binds (e.g., `8080` on Cloud Run). |
| `NODE_ENV` | yes | `development` | `production` enables stricter defaults (X-User-Id rejected unless `ALLOW_X_USER_ID=1`). |
| `JWT_SECRET` | yes | dev placeholder | A long random string. **Rotate to invalidate all tokens.** |
| `ALLOW_X_USER_ID` | no | `1` (dev) | Leave unset in production. Setting to `1` in production re-enables the legacy header — only do this for incident response. |
| `CORS_ORIGINS` | no | `*` (dev) | Comma-separated origin list. `*` allows everything; production MUST restrict. |
| `UPLOADS_DIR` | no | `uploads` (relative) | Absolute path or mounted volume. Future M-? will replace with object storage. |

---

## 3. Local development flow

```powershell
# from repo root
npm install
docker compose up -d postgres
cp .env.example .env
npx prisma migrate dev          # applies all migrations on local DB
npm run db:seed                 # six personas + content + reports + media
npm run api:dev                 # http://localhost:3000/v1

# Apply migrations to the test DB once for e2e:
$env:DATABASE_URL = "postgresql://prism:prism@localhost:5433/prism_club_test?schema=public"
npx prisma migrate deploy
Remove-Item Env:DATABASE_URL

# Flutter web
cd apps/mobile
flutter pub get
flutter run -d chrome
```

The smoke script (`bash scripts/smoke.sh`) hits the running API and uses the
legacy `X-User-Id` header (dev mode keeps it).

---

## 4. Production build (API)

### Native build

```bash
npm install --no-audit --no-fund
npm run build               # runs `prisma generate` + `nest build`
NODE_ENV=production JWT_SECRET=... DATABASE_URL=... \
  CORS_ORIGINS=https://club.example.com \
  npm run start:prod        # runs `node apps/api/dist/main` via the workspace
```

### Container build

```bash
docker build -t prism-club-api:alpha -f apps/api/Dockerfile .
docker run --rm -p 3000:3000 \
  -e NODE_ENV=production \
  -e DATABASE_URL=postgresql://user:pw@host:5432/prism_club?schema=public \
  -e JWT_SECRET=$(openssl rand -hex 32) \
  -e CORS_ORIGINS=https://club.example.com \
  -v $(pwd)/uploads:/app/uploads \
  prism-club-api:alpha
```

The Dockerfile is a multi-stage Node 20 build that:

1. Installs all workspace deps and the Prisma client.
2. Compiles the NestJS app to `apps/api/dist`.
3. Prunes dev dependencies.
4. Copies `dist/`, `node_modules/`, and the Prisma schema/migrations into a
   slimmer runtime image.
5. Exposes port 3000 and runs `node apps/api/dist/main`.

The image does NOT run migrations on boot — your deployment pipeline
should run `npm run prisma:migrate:deploy` against the target DB before
rolling new pods.

### Database migrations on deploy

```bash
DATABASE_URL=postgresql://... npm run prisma:migrate:deploy
```

`prisma migrate deploy` is the production-safe flavour: it applies pending
migrations without prompting, never resets, never generates new migrations.

---

## 5. Flutter web build

```bash
cd apps/mobile
flutter pub get
flutter build web --no-tree-shake-icons \
  --dart-define=API_BASE_URL=https://api.example.com/v1
```

The compiled bundle lives in `apps/mobile/build/web`. Serve it behind any
static host (S3 + CloudFront, Cloudflare Pages, nginx, etc.). It is purely
a client of the API; no server-side rendering, no Node runtime.

Compile-time defines:

| Define | Default | Notes |
|---|---|---|
| `API_BASE_URL` | derived from platform (see `lib/core/config.dart`) | The Dio base URL. Must end with `/v1`. |

---

## 6. Health / readiness

| Endpoint | Purpose | Notes |
|---|---|---|
| `GET /v1/health` | Liveness | Always returns `{ ok: true }` if the process is up. |
| `GET /v1/health/ready` | Readiness | Returns 200 + `{ ok: true, db: 'up' }` when Postgres is reachable; otherwise 503 with the DB error. Use for load balancer / k8s readinessProbe. |

---

## 7. Things explicitly OUT of scope here

- HTTPS termination (handle at your reverse proxy / load balancer).
- WAF / rate limiting (planned post-Alpha — see `NEXT_BACKLOG.md`).
- Centralized logging, metrics, and tracing.
- Production media storage (currently a filesystem path — see `NEXT_BACKLOG.md`).
- Background workers / message queues (none yet).
- Multi-region replication.
- Native mobile distribution (App Store / Google Play).

---

## 8. Smoke test against a deployed environment

`scripts/smoke.sh` accepts `API=...` to retarget. Example:

```bash
API=https://api.example.com/v1 bash scripts/smoke.sh
```

The script currently uses the legacy `X-User-Id` header, which means a
production deployment with `NODE_ENV=production` will reject it. For now,
either keep `ALLOW_X_USER_ID=1` for the alpha environment, or switch the
smoke script to call `POST /v1/auth/login` and use the JWT — that update
is on the post-Alpha backlog.
