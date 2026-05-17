# PRISM Club — Staging Bring-Up Checklist

The single page an operator follows the first time they deploy a Beta
staging environment. Every step is a box you tick; every command is
written out in full. If you finish this page with every box checked
and the §15 sign-off filled in, staging is ready for the
[Cutover Rehearsal](CUTOVER_REHEARSAL.md).

> **Scope.** Bring-up only. Day-2 operations (smoke, QA, rollback) live
> in their own docs — see §13 for the hand-off.

Pairs with:

- [STAGING_SETUP.md](STAGING_SETUP.md) — the full setup walkthrough this
  checklist condenses
- [STAGING_SMOKE.md](STAGING_SMOKE.md) — how to smoke the result
- [CUTOVER_REHEARSAL.md](CUTOVER_REHEARSAL.md) — the next step after
  bring-up
- [DEPLOYMENT.md](DEPLOYMENT.md) — env matrix + container build
- [.env.staging.example](../.env.staging.example) — placeholder env
- [docker-compose.staging.example.yml](../docker-compose.staging.example.yml)
  — single-VM runtime template

---

## 1. Required decisions (before you touch anything)

Lock these in writing before running a single command. Changing them
mid-bring-up wastes more time than the discussion did.

| Decision | Choice | Notes / fallback |
|---|---|---|
| API host (domain) | `https://api.staging.<your-domain>` | TLS terminated at the LB / proxy; the API does NOT serve HTTPS itself. |
| Flutter web host (domain) | `https://app.staging.<your-domain>` | Static bundle; separate origin from API for clean CORS. |
| Admin web host (domain) | `https://admin.staging.<your-domain>` | Static bundle; separate origin from app for clean CORS. |
| Postgres provider | self-hosted (single VM via compose) **or** managed (RDS / Cloud SQL / Neon / Supabase) | Managed is recommended once you need backups + PITR. Self-hosted is fine for a one-engineer rehearsal. |
| Media storage mode | `local` **for first boot**, `s3` before sharing the URL | `MEDIA_STORAGE_MODE=local` survives one container, not a restart. Flip per §10 before external testers. |
| Events client mode | `mock` **for first boot**, `prism` after upstream creds are ready | `EVENTS_CLIENT_MODE=mock` removes one integration variable while you stabilize the rest. Flip per §9. |
| Notification delivery | `noop` (Beta default — don't change) | Provider boundaries are stubs at Beta. |
| Smoke auth mode | `legacy` (with `ALLOW_X_USER_ID=1`) **or** `jwt` | Either works against staging. `jwt` is cleaner; `legacy` matches the script's local-dev default. See §7. |

Write the chosen values into your ops vault NOW, before §2.

- [ ] API host name decided and recorded.
- [ ] App host name decided and recorded.
- [ ] Admin host name decided and recorded.
- [ ] Postgres provider chosen.
- [ ] Media storage mode chosen for first boot.
- [ ] Events client mode chosen for first boot.
- [ ] Smoke auth mode chosen for first boot.

---

## 2. File copy + populate

All of these stay on the deploy host. **Do NOT commit any of them.**
The `.gitignore` already covers them:
`.env.staging`, `docker-compose.staging.yml`, and the dotted variants.

### 2.1 Copy the env template

```bash
cp .env.staging.example .env.staging
```

- [ ] File copied.
- [ ] Open `.env.staging` and fill in every `<...>` placeholder.
      Minimum required (per `.env.staging.example`):
      `DATABASE_URL`, `JWT_SECRET`, `CORS_ORIGINS`.
- [ ] Build-metadata envs filled if you're tagging the deploy:
      `APP_VERSION`, `GIT_SHA`, `BUILD_TIME`,
      `RELEASE_CHANNEL=staging`.
- [ ] `EVENTS_CLIENT_MODE=mock` (verify; this is the safe first boot).
- [ ] `MEDIA_STORAGE_MODE=local` (verify; flip per §10).
- [ ] `NOTIFICATION_DELIVERY_MODE=noop` (verify; Beta default).
- [ ] `ALLOW_X_USER_ID=1` if you plan to run the legacy-mode smoke
      script during cut-over (acceptable for staging only — production
      MUST leave it unset).

### 2.2 (compose path only) Copy the runtime template

Skip this if you're deploying to k8s / Cloud Run / managed container
platform.

```bash
cp docker-compose.staging.example.yml docker-compose.staging.yml
```

- [ ] File copied.
- [ ] Open `docker-compose.staging.yml` and confirm `image:` points
      at the registry tag you'll deploy (or remove it to build
      locally — see §5).
- [ ] If switching to a managed DB: remove the `postgres:` service
      and the `depends_on:` block; set the api service's
      `DATABASE_URL` to the managed connection string.
- [ ] If running S3 instead of local: §10 applies — keep
      `MEDIA_STORAGE_MODE=local` for first boot, flip later.

### 2.3 Fill secrets

The secrets that must NEVER appear in plain env, logs, or git:

| Variable | How to generate / obtain |
|---|---|
| `JWT_SECRET` | `openssl rand -hex 32` |
| `DATABASE_URL` | Managed DB connection string from the provider console, OR the self-hosted `postgresql://prism_staging:<password>@postgres:5432/prism_club_staging?schema=public` shape |
| `POSTGRES_PASSWORD` | `openssl rand -base64 24 \| tr '+/' '-_' \| head -c 32` (avoid shell-special chars) |
| `S3_ACCESS_KEY_ID` / `S3_SECRET_ACCESS_KEY` | IAM key minted with `s3:PutObject` + `s3:GetObject` on the staging bucket only |
| `PRISM_EVENTS_API_KEY` | Upstream-provided staging key (empty if `EVENTS_CLIENT_MODE=mock`) |

- [ ] `JWT_SECRET` is fresh (never reused from any other environment).
- [ ] `DATABASE_URL` is staging-only and never the production string.
- [ ] No secret value appears in `git log -p`, terminal scrollback,
      or any shared chat.

---

## 3. Infrastructure checklist

The things that must exist before §4 will succeed. Reuse organization-
standard tooling — none of these are project-specific.

- [ ] DNS records for all three hostnames point at the LB / proxy
      that fronts staging.
- [ ] TLS certificate provisioned for api / app / admin hosts.
- [ ] Postgres 16 reachable from where the API will run; DB +
      role created per [STAGING_SETUP.md](STAGING_SETUP.md) §4.1.
- [ ] (S3 path) Bucket created, IAM key scoped to it. Public-read on
      object prefix `staging-uploads/` so the Flutter client can
      fetch images.
- [ ] (Container image) `prism-club-api:<sha-or-tag>` built locally
      (`docker build -t prism-club-api:staging -f apps/api/Dockerfile .`)
      or pulled to the host.
- [ ] (Flutter web) Bundle built with the staging API URL:
      ```bash
      cd apps/mobile
      flutter pub get
      flutter build web --no-tree-shake-icons \
        --dart-define=API_BASE_URL=https://api.staging.<your-domain>/v1
      ```
      and uploaded to the app host.
- [ ] (Admin web) Bundle built and uploaded:
      ```bash
      cd apps/admin
      npm install
      VITE_API_BASE_URL=https://api.staging.<your-domain>/v1 npm run build
      ```
      → upload `apps/admin/dist/` to the admin host.

---

## 4. Migration checklist

The image does NOT run migrations on boot. Apply them as a one-shot
step before the API container starts serving traffic.

```bash
# Pre-deploy status check
DATABASE_URL="<staging-database-url>" npx prisma migrate status
# Expect: pending migration list, or "Database schema is up to date!"

# Apply
DATABASE_URL="<staging-database-url>" npx prisma migrate deploy
# Expect: exit code 0; each applied migration name printed.

# Post-deploy sanity
DATABASE_URL="<staging-database-url>" npx prisma migrate status
# Expect: "Database schema is up to date!"
```

- [ ] `migrate status` pre-deploy captured (recorded in your bring-up
      log).
- [ ] `migrate deploy` exits 0.
- [ ] `migrate status` post-deploy confirms "up to date".
- [ ] Bootstrap the first CURATOR / MODERATOR / ADMIN account via SQL
      (per [STAGING_SETUP.md](STAGING_SETUP.md) §4.3). Record the
      `<admin-uuid>` in your ops vault.
- [ ] (Optional but recommended for staging) Seed demo personas:
      ```bash
      CONFIRM_DESTRUCTIVE_SEED=1 \
        DATABASE_URL="<staging-database-url>" \
        NODE_ENV=production \
        npm run db:seed
      ```
      The `CONFIRM_DESTRUCTIVE_SEED=1` flag is the guardrail from
      `prisma/seed.ts` — it forces an explicit acknowledgement that
      the seed will truncate every table first. Skip this step if
      staging is reachable from the public internet and you don't
      want the well-known persona UUIDs alive there.

---

## 5. First boot checklist

### 5.1 (compose path)

```bash
docker compose -f docker-compose.staging.yml --env-file .env.staging up -d
docker compose -f docker-compose.staging.yml --env-file .env.staging ps
```

- [ ] `docker compose ... config` validates without error (do this
      before `up -d` if you haven't already).
- [ ] `postgres` container is `Up (healthy)`.
- [ ] `api` container is `Up (healthy)` — the readiness healthcheck
      defined in the compose file polls `/v1/health/ready` and only
      reports `healthy` once Postgres is reachable.

### 5.2 (managed platform path)

- [ ] Container image rolled with the `.env.staging` values forwarded
      to the platform's secret / env store.
- [ ] At least one pod reports ready against the platform's probe.
- [ ] (k8s) `readinessProbe: GET /v1/health/ready` wired with a
      ~10s interval.

---

## 6. Health / version checks

Three public endpoints. None require auth. All must succeed before
moving on.

```bash
# Liveness
curl -sS https://api.staging.<your-domain>/v1/health
# Expect: {"ok":true}

# Readiness (DB reachable?)
curl -sS -o /dev/null -w "%{http_code}\n" https://api.staging.<your-domain>/v1/health/ready
# Expect: 200

# Build metadata — confirms which image is actually serving
curl -sS https://api.staging.<your-domain>/v1/health/version | jq .
# Expect: { "app_version": "...", "git_sha": "...", "build_time": ...,
#          "release_channel": "staging", "node_env": "production" }
```

- [ ] `/v1/health` returns `{"ok": true}`.
- [ ] `/v1/health/ready` returns 200.
- [ ] `/v1/health/version` returns a sane payload, `release_channel`
      is `staging`, `app_version` + `git_sha` match the image you
      intended to deploy.

If `release_channel` is `unknown`, your `RELEASE_CHANNEL` env didn't
make it to the container. Fix and roll once before continuing.

---

## 7. JWT smoke command

The smoke script lives at `scripts/smoke.sh`. It has two auth modes
(`SMOKE_AUTH_MODE=legacy|jwt`). Pick whichever matches your decision
in §1.

### 7.1 JWT mode (recommended for staging that mirrors production auth)

```bash
SMOKE_AUTH_MODE=jwt \
  API=https://api.staging.<your-domain>/v1 \
  bash scripts/smoke.sh
```

- The script calls `POST /v1/auth/login` once per seeded persona,
  caches the bearer tokens, and uses `Authorization: Bearer <jwt>`
  for the rest of the run.
- Works whether `ALLOW_X_USER_ID` is set or unset on the target.
- **Requires §4's optional seed step to have run** (the script's
  hardcoded persona UUIDs must exist in the DB).

### 7.2 Legacy mode (matches dev/local behavior)

```bash
API=https://api.staging.<your-domain>/v1 bash scripts/smoke.sh
```

- The script sends `X-User-Id: <persona-uuid>` on every request.
- Requires `ALLOW_X_USER_ID=1` on the API pod (acceptable for staging,
  not for production).

### 7.3 Either mode

- [ ] Script prints `Smoke target: <api-url>` and
      `Auth mode: legacy|jwt` at the top — capture this header in the
      bring-up log.
- [ ] Script ends with `All smoke checks passed.`
- [ ] If anything fails, do NOT retry blindly. See
      [STAGING_SMOKE.md](STAGING_SMOKE.md) §4 for the failure
      interpretation table.

---

## 8. Admin web checklist

The Vite + React SPA at `https://admin.staging.<your-domain>`.

- [ ] Load the URL in a fresh browser tab (Incognito recommended).
- [ ] Login form renders; "API base URL" input defaults to the value
      you set via `VITE_API_BASE_URL` at build time (§3).
- [ ] Paste the `<admin-uuid>` from §4 into the user_id field, submit
      → dashboard renders.
- [ ] Top-bar shows nickname + role chips (`ADMIN` at minimum).
- [ ] **Beta launch checklist card** at the top of the dashboard:
  - [ ] `API ready` → green (`db=up`).
  - [ ] `Build` → matches `/v1/health/version` from §6 (same
        `app_version` / `git_sha` / `release_channel: staging`).
  - [ ] `Events client` → green when in `mock` mode AND
        `parse_failed=0` AND `http_errors=0` (which they are at
        first boot).
  - [ ] `Analytics (30d)` → reports event types and counts. If
        you ran §7's smoke, `AUTH_LOGIN` should be ≥ 1 already.
  - [ ] `Open reports` / `Pending contributions` → counts render
        (may be 0 on a fresh seed).
- [ ] Sign out — redirected to login form, localStorage token gone.

---

## 9. Flutter web checklist

The static bundle at `https://app.staging.<your-domain>`.

- [ ] Load the URL in a fresh browser tab.
- [ ] Login picker renders (Beta has no signup).
- [ ] Pick a seeded persona; redirected to `/home`.
- [ ] DevTools → Network → at least one request to the API host
      includes `Authorization: Bearer <jwt>`. The JWT lives in
      localStorage.
- [ ] `/home` renders the bundle (followed-room updates, recommended
      rooms / events, trending posts, active hubs, recent saves,
      unread notification count). At least one section has content
      if the seed was applied.
- [ ] **Don't run the full QA script yet.** That's the rehearsal step
      (see §13).

---

## 10. S3 / media mode flip checklist

Run this step before sharing the staging URL with external testers.
`local` mode is acceptable for the first smoke; it does NOT survive a
container restart or horizontal scale.

- [ ] S3-compatible bucket exists; IAM key scoped to it.
- [ ] Update `.env.staging`:
  - `MEDIA_STORAGE_MODE=s3`
  - `MEDIA_PUBLIC_BASE_URL=https://<cdn-or-bucket-host>`
  - `S3_BUCKET`, `S3_REGION`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`
  - `S3_ENDPOINT` + `S3_FORCE_PATH_STYLE=1` if using R2 / MinIO
  - Keep `S3_OBJECT_PREFIX=staging-uploads`
- [ ] Roll the API pod / container.
- [ ] Re-run the **media upload** subset of smoke OR manually:
  ```bash
  TOKEN=$(curl -sS -X POST https://api.staging.<your-domain>/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"user_id":"11111111-1111-1111-1111-111111111111"}' | jq -r .access_token)
  curl -sS -X POST -H "Authorization: Bearer $TOKEN" \
    -F "file=@./small.jpg;type=image/jpeg" \
    https://api.staging.<your-domain>/v1/media/upload | jq .
  ```
  - [ ] Response `url` starts with `MEDIA_PUBLIC_BASE_URL`.
  - [ ] That URL is fetchable in a browser; the image renders.
  - [ ] Object is visible in the bucket under `staging-uploads/`.

If the upload fails with `500`, `S3MediaStorage` could not connect —
re-check the bucket region, endpoint, and IAM perms. Config is
validated **lazily on first upload**, so a misconfigured S3 doesn't
crash the API at boot; it surfaces here.

---

## 11. PRISM EVENT mode flip checklist

Run this step once the upstream PRISM EVENT / CONTENIDO endpoint has
agreed to send staging traffic. Skip if you don't have upstream creds
yet — `mock` mode is good enough for the first smoke + admin UI sanity.

- [ ] Upstream URL + API key + agreed rate limit known.
- [ ] Update `.env.staging`:
  - `EVENTS_CLIENT_MODE=prism`
  - `PRISM_EVENTS_API_BASE_URL=https://<upstream-host>/api/v1`
  - `PRISM_EVENTS_API_KEY=<upstream-key>` (if required)
  - `PRISM_EVENTS_TIMEOUT_MS=4000` (tune later if upstream is slow)
- [ ] Roll the API pod / container.
- [ ] Verify the diagnostic:
  ```bash
  TOKEN=$(curl -sS -X POST https://api.staging.<your-domain>/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"user_id":"<admin-uuid>"}' | jq -r .access_token)
  curl -sS -H "Authorization: Bearer $TOKEN" \
    https://api.staging.<your-domain>/v1/admin/events-client/status | jq .
  ```
  - [ ] `mode: "prism"` (not `"mock"`).
  - [ ] `base_url_configured: true`.
  - [ ] All counters zero before the first request.
- [ ] Hit `/v1/events/search?q=<known-keyword>` once. Re-fetch the
      diagnostic — `parsed_ok` should be > 0, `parse_failed` should
      remain 0.

If `parse_failed > 0`, the upstream payload doesn't match the
contract — see [EVENTS_INTEGRATION.md](EVENTS_INTEGRATION.md) §4
(zod schema + per-row skip semantics).

---

## 12. Rollback checkpoint

Before declaring bring-up complete, prove you can roll back. A
bring-up that hasn't been rolled back at least once isn't ready for
the cut-over rehearsal — the rehearsal will exercise rollback as a
real step.

- [ ] Previous image tag recorded (`docker image ls prism-club-api`
      or the platform registry view).
- [ ] DB backup snapshot identifier from within the last 60 minutes
      recorded.
- [ ] One of the rollback paths from
      [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) §7 has been
      walked **on this staging environment** at least once. Image
      revert (Path A) is enough — 5-minute budget.
- [ ] After rollback rehearsal, roll forward again to the target sha
      so staging is back on the current image.

---

## 13. Hand-off to next step

When every box in §1 through §12 is checked, staging is **bring-up
complete**. Hand off to:

- [Cutover rehearsal](CUTOVER_REHEARSAL.md) — staging dry-run of the
  production cut-over. Runs against this same staging environment.
- [Beta QA script](BETA_QA_SCRIPT.md) — manual persona-by-persona QA.
  The rehearsal executes this; you can also run a single pass now if
  you want extra confidence.

Do NOT advance to production cut-over without a green rehearsal
result.

---

## 14. Quick reference card

```bash
# Setup
cp .env.staging.example .env.staging
cp docker-compose.staging.example.yml docker-compose.staging.yml   # compose path only
openssl rand -hex 32                                                # → JWT_SECRET

# Migrate
DATABASE_URL="<staging-database-url>" npx prisma migrate deploy

# Boot (compose path)
docker compose -f docker-compose.staging.yml --env-file .env.staging up -d

# Health probes
curl -sS https://api.staging.<your-domain>/v1/health
curl -sS https://api.staging.<your-domain>/v1/health/ready
curl -sS https://api.staging.<your-domain>/v1/health/version | jq .

# Smoke (pick one)
SMOKE_AUTH_MODE=jwt API=https://api.staging.<your-domain>/v1 bash scripts/smoke.sh
API=https://api.staging.<your-domain>/v1 bash scripts/smoke.sh          # legacy mode

# Reset between rehearsal runs (staging only):
DATABASE_URL="<staging-database-url>" npx prisma migrate reset --force
CONFIRM_DESTRUCTIVE_SEED=1 NODE_ENV=production \
  DATABASE_URL="<staging-database-url>" npm run db:seed
```

---

## 15. Sign-off

Paste the filled version into the bring-up log / ticket:

```
PRISM Club — Staging Bring-Up Sign-off
======================================
Date / window       : <YYYY-MM-DD HH:MM-HH:MM TZ>
Operator            : <name>
On-call partner     : <name or "n/a">

Targets
  API host          : https://api.staging.<your-domain>
  App host          : https://app.staging.<your-domain>
  Admin host        : https://admin.staging.<your-domain>
  Postgres provider : <self-hosted compose | RDS | Cloud SQL | Neon | ...>
  Postgres reach    : <host:port/db>

Image
  Candidate sha     : <git-sha>
  app_version       : <observed from /v1/health/version>
  release_channel   : staging

Modes (first boot)
  EVENTS_CLIENT_MODE        : <mock | prism>
  MEDIA_STORAGE_MODE        : <local | s3>
  NOTIFICATION_DELIVERY_MODE: noop
  ALLOW_X_USER_ID           : <1 | unset>
  Smoke auth mode (§7)      : <legacy | jwt>

Health (§6)
  /v1/health               : <PASS / FAIL>
  /v1/health/ready         : <PASS / FAIL>
  /v1/health/version       : <PASS / FAIL — note any mismatch>

Migration (§4)
  prisma migrate deploy    : <PASS / FAIL — migrations applied>
  Bootstrap admin uuid     : <uuid> (stored in <vault location>)
  Seed applied             : <yes / no>

Smoke (§7)                 : <PASS / FAIL — mode + runtime>

Admin web (§8)
  Login                    : <PASS / FAIL>
  Beta launch card         : <PASS / FAIL — anything red?>
  Sign out                 : <PASS / FAIL>

Flutter web (§9)
  Login picker             : <PASS / FAIL>
  /home renders            : <PASS / FAIL>

Mode flips
  S3 flip (§10)            : <n/a | PASS / FAIL — upload URL fetchable>
  PRISM events flip (§11)  : <n/a | PASS / FAIL — diagnostic clean>

Rollback rehearsal (§12)   : <PASS / FAIL — wall-clock>

Outstanding items          : <list, or "none">

Bring-up verdict           : <READY for cutover rehearsal | NOT READY>

Signed
  Operator        : <name + date>
  On-call partner : <name + date>
```

`Bring-up verdict: READY` is the only acceptable handoff state. Move
to NOT READY → fix → re-run the relevant section → re-sign.
