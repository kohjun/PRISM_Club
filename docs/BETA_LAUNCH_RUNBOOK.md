# PRISM Club — Beta Launch Runbook

Operational guide for cutting the first Beta release into a real
environment. Pairs with:

- [BETA_READINESS.md](BETA_READINESS.md) — what the code looks like at
  the freeze
- [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md) — manual QA flows for cut-over
- [CUTOVER_REHEARSAL.md](CUTOVER_REHEARSAL.md) — **staging dry-run of
  this runbook; required before production cut-over**
- [DEPLOYMENT.md](DEPLOYMENT.md) — env matrix + container build
- [EVENTS_INTEGRATION.md](EVENTS_INTEGRATION.md) — upstream events
- [ANALYTICS.md](ANALYTICS.md) — analytics taxonomy + privacy rules
- [NEXT_BACKLOG.md](NEXT_BACKLOG.md) — what is intentionally deferred

This runbook describes the **execution** side of Beta: who does what,
when, in what order, what to monitor while doing it, and how to back out
if something breaks. It does NOT describe the code freeze (that lives in
`BETA_READINESS.md` §7) or the upstream contract (that lives in
`EVENTS_INTEGRATION.md`).

> **Audience:** the engineer running the Beta cut-over plus the on-call
> partner shadowing it. Both should have read this document end-to-end
> before deploy day.

---

## 1. Pre-launch checklist

Run this list T-72h to T-24h before the planned launch window. None of
these block on the cut-over itself; missing any one of them is a NO-GO
signal.

### Code + freeze

- [ ] Release branch (`main` or `release/beta-1`) at
      `chore: prepare beta readiness` or a later non-feature commit.
- [ ] `git log --oneline -5` reviewed by the on-call partner.
- [ ] No open PRs touching `prisma/schema.prisma`, `prisma/migrations/`,
      or any breaking controller signatures.

### Headless verification (must all be green at HEAD)

- [ ] `npm install` succeeds at repo root.
- [ ] `npm run api:test` → **158 / 158** green.
- [ ] `npm run api:test:e2e` → **43 / 43** green.
- [ ] `npx tsc --noEmit -p apps/api/tsconfig.json` → exit 0.
- [ ] `npx tsc --noEmit -p apps/admin/tsconfig.json` → exit 0.
- [ ] `cd apps/mobile && flutter analyze` → no errors / warnings
      (info-only output OK).
- [ ] `cd apps/mobile && flutter test` → **53 / 53** green.
- [ ] `cd apps/mobile && flutter build web --no-tree-shake-icons` →
      succeeds.

### Infrastructure prerequisites

- [ ] Managed Postgres 16 reachable from the API runtime; credentials in
      the deployment secret store.
- [ ] Database backup verified within the last 24 hours (snapshot or
      pg_dump). **Record the backup id / timestamp in §7 Rollback.**
- [ ] Point-in-time recovery (PITR) enabled on the DB if the platform
      supports it.
- [ ] S3-compatible bucket created for media (R2 / AWS S3 / MinIO). IAM
      access key + secret minted with `s3:PutObject` + `s3:GetObject` on
      the bucket only.
- [ ] DNS records for the API host and the admin web host point at the
      load balancer / reverse proxy.
- [ ] TLS certificate provisioned for both hosts (Let's Encrypt or
      managed equivalent).
- [ ] Container image pushed to the registry: `prism-club-api:<git-sha>`
      (multi-stage Node 20 build per `apps/api/Dockerfile`).
- [ ] Admin web static bundle built with
      `VITE_API_BASE_URL=https://<api-host>/v1` and uploaded to the
      static host.
- [ ] Flutter web bundle built with
      `--dart-define=API_BASE_URL=https://<api-host>/v1` and uploaded to
      the static host.

### Identity + role bootstrap

- [ ] At least one CURATOR / MODERATOR / ADMIN account exists in the
      target DB. **The seed personas are dev / staging only.** Never
      run `npm run db:seed` against production — the seed begins with
      `clearAll`, which truncates every table. The CLI refuses with
      exit code 2 when `NODE_ENV=production` and
      `CONFIRM_DESTRUCTIVE_SEED` is not set, but the guard is a
      safety net, not a license. Create the production admin row
      manually via SQL:
      ```sql
      INSERT INTO user_roles (id, user_id, role, source)
      VALUES (gen_random_uuid(), '<production-user-uuid>', 'ADMIN', 'manual-bootstrap');
      ```
- [ ] Record the bootstrap account's user_id + nickname in your
      ops vault (you will need it to log into the admin web).

### Comms

- [ ] Launch window confirmed with stakeholders (no overlapping
      maintenance on adjacent PRISM services).
- [ ] On-call rotation aware of the cut-over and which monitoring hooks
      to watch (see §6).
- [ ] Status page updated to "Beta launch in progress" 15 minutes before
      the window opens.

---

## 2. Environment variable checklist

The full matrix is in [DEPLOYMENT.md](DEPLOYMENT.md) §2. This is the
launch-day subset, sorted by risk.

| Variable | Beta value | Where it lives | Risk if wrong |
|---|---|---|---|
| `JWT_SECRET` | Fresh `openssl rand -hex 32` output | Secret store only | Token forgery / mass logout if rotated mid-flight |
| `DATABASE_URL` | Managed Postgres URI | Secret store | Connection storm or hits the wrong DB |
| `NODE_ENV` | `production` | Plain env | Loosens guards; X-User-Id allowed if also `ALLOW_X_USER_ID=1` |
| `ALLOW_X_USER_ID` | **unset** | Plain env | Legacy header re-enabled (auth bypass) |
| `CORS_ORIGINS` | `https://<club-host>,https://<admin-host>` | Plain env | Browser clients break or any origin can hit the API |
| `API_PORT` | Whatever the platform binds (e.g. `8080`) | Plain env | Container won't accept traffic |
| `EVENTS_CLIENT_MODE` | `prism` (recommended) | Plain env | Falls back to mock fixture data if upstream URL missing |
| `PRISM_EVENTS_API_BASE_URL` | Production upstream base URL | Plain env | Events surfaces empty; see §6 monitoring |
| `PRISM_EVENTS_API_KEY` | Provider key (if upstream requires it) | Secret store | 401/403 from upstream; clients return empty |
| `PRISM_EVENTS_TIMEOUT_MS` | `4000` (start) | Plain env | Slow upstream causes long requests; tune down if needed |
| `MEDIA_STORAGE_MODE` | `s3` (recommended) | Plain env | Local FS fallback won't survive restarts |
| `MEDIA_PUBLIC_BASE_URL` | `https://<cdn-or-bucket-host>` | Plain env | Browser can't fetch uploaded images |
| `S3_BUCKET` / `S3_REGION` / `S3_ACCESS_KEY_ID` / `S3_SECRET_ACCESS_KEY` | Bucket creds | Secret store | First upload fails; lazy-config error |
| `S3_ENDPOINT` | Only for R2 / MinIO | Plain env | AWS default used inadvertently |
| `S3_FORCE_PATH_STYLE` | `1` for MinIO | Plain env | URL format mismatch |
| `NOTIFICATION_DELIVERY_MODE` | `noop` (default at Beta) | Plain env | If flipped without provider envs, email/push silently SKIPPED |
| `UPLOADS_DIR` | n/a in s3 mode; `/app/uploads` in local mode | Plain env | Container loses uploads on restart |

**Sanity checks**:

```bash
# Print the relevant env (redact secrets) from a running container:
$ docker exec <container> env | grep -E '^(NODE_ENV|EVENTS_CLIENT_MODE|MEDIA_STORAGE_MODE|NOTIFICATION_DELIVERY_MODE|CORS_ORIGINS|ALLOW_X_USER_ID)='
NODE_ENV=production
EVENTS_CLIENT_MODE=prism
MEDIA_STORAGE_MODE=s3
NOTIFICATION_DELIVERY_MODE=noop
CORS_ORIGINS=https://club.example.com,https://admin.example.com
# ALLOW_X_USER_ID MUST be empty here.
```

`JWT_SECRET`, `DATABASE_URL`, and the `S3_*` / `PRISM_EVENTS_API_KEY`
secrets must NEVER appear in shell output, log lines, error responses,
or git history. If you discover one in the open: rotate immediately
(§7 Rollback covers the rotation flow).

---

## 3. Database migration checklist

Beta runs against a fresh DB. After the first launch, every subsequent
deploy uses the same migration-then-rollout flow.

### Pre-deploy (T-30m)

- [ ] Confirm a backup exists from within the last 60 minutes. If using
      a managed provider, take an on-demand snapshot now and record the
      snapshot id.
- [ ] List the migrations the new image will apply:
      ```bash
      DATABASE_URL=<prod-uri> npx prisma migrate status
      ```
      Expect "Database schema is up to date!" if no new migrations are
      pending; otherwise the list of migrations to be applied.
- [ ] Compare the list to the diff between the previously-deployed git
      sha and the target sha. Reject the cut-over if a migration appears
      that wasn't reviewed.

### Deploy step (T-0)

- [ ] From the deploy host (NOT from a developer laptop unless that's
      the documented path):
      ```bash
      DATABASE_URL=<prod-uri> npx prisma migrate deploy
      ```
      `prisma migrate deploy` applies pending migrations without
      prompting, never resets, never generates new migrations.
- [ ] Verify exit code 0. The command prints each migration applied;
      capture the output to the cut-over log.
- [ ] Sanity-check the schema against the deployed code:
      ```bash
      DATABASE_URL=<prod-uri> npx prisma migrate status
      ```
      Expect "Database schema is up to date!".

### Post-migration sanity

- [ ] Connect with `psql` and verify a few tables exist:
      ```sql
      \dt analytics_events
      \dt user_follows
      \dt reports
      ```
- [ ] Check the migration history table:
      ```sql
      SELECT migration_name, finished_at
      FROM _prisma_migrations
      ORDER BY finished_at DESC
      LIMIT 5;
      ```
- [ ] Bootstrap the admin role row (see §1 Identity bootstrap) if this
      is the first deploy.

### Failure modes

- **`P1000` (auth)**: `DATABASE_URL` credentials are wrong. Fix the
  secret, rerun migrate deploy. Do NOT roll the API container forward
  until schema matches code.
- **`P3009` (migration failed)**: One of the migrations errored
  mid-flight. Postgres typically rolls back the failed migration's
  transaction. Investigate the error before retrying. If a partial
  schema change leaked, restore from the pre-migration snapshot and
  re-run.
- **Drift**: `prisma migrate status` reports drift after the deploy.
  Halt rollout, capture the diff (`prisma migrate diff`), and decide
  with the on-call partner whether to forward-fix or roll back.

---

## 4. Deployment sequence

```
T-72h ──── pre-launch checklist (§1)
T-60m ──── stakeholder ack + status page banner up
T-30m ──── migration dry-run + backup snapshot (§3 pre-deploy)
T-15m ──── pull container image, validate envs against §2
T-5m  ──── stop accepting new admin web sessions (DNS TTL ≤ 60s)
T-0   ──── apply migrations (§3 deploy step)
T+0   ──── roll new API pods (one at a time; wait for readiness probe)
T+5m  ──── smoke checklist (§5)
T+10m ──── persona QA (§9 + BETA_QA_SCRIPT.md)
T+20m ──── flip status page to "Beta live"
T+1h  ──── first hour monitoring window (§8)
T+24h ──── post-launch retro (§10)
```

### Step-by-step

1. **Apply migrations** — `npx prisma migrate deploy` against the prod
   DB. Wait for exit 0.
2. **Roll new API pods** — push the new image tag; let the orchestrator
   recreate pods one at a time. Each new pod must:
   - pass `GET /v1/health` (process up)
   - pass `GET /v1/health/ready` (DB reachable)
   before the orchestrator routes traffic to it.
3. **Verify build metadata** — confirm the image that's actually
   serving traffic is the one you intended:
   ```bash
   curl -sS https://<api-host>/v1/health/version | jq .
   ```
   Expect `app_version` + `git_sha` matching the release tag and
   `release_channel: "beta"` (or `"production"`). Capture the response
   in the cut-over log.
4. **Verify event client diagnostic** — once one pod is serving,
   ```bash
   curl -sS -H "Authorization: Bearer <admin-jwt>" \
     https://<api-host>/v1/admin/events-client/status | jq .
   ```
   Expect `mode: "prism"`, `base_url_configured: true`, all stats zero
   (until the first user request).
5. **Verify analytics summary** —
   ```bash
   curl -sS -H "Authorization: Bearer <admin-jwt>" \
     https://<api-host>/v1/admin/analytics/summary | jq .
   ```
   Expect `window_days: 30` and an empty / sparse `counts` array.
6. **Verify admin web** — load the admin host in a browser. Log in with
   the bootstrap user; the dashboard renders.
7. **Run smoke** — §5.
8. **Run persona QA** — §9, with [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md)
   open in another tab.
9. **Flip status page** — "Beta live."

### Rolling deploys (post-launch)

Every subsequent deploy follows the same shape:

```
build + push image → run migrate deploy → roll pods → smoke → done
```

The image deliberately does NOT run migrations on boot (see
DEPLOYMENT.md §4). Always migrate first, then roll.

---

## 5. Smoke test checklist (post-deploy)

The headless verification suite covered every code path in isolation.
This smoke is a live end-to-end gut check against the deployed
environment.

```bash
# Default (legacy header) — requires ALLOW_X_USER_ID=1 on the target.
API=https://<api-host>/v1 bash scripts/smoke.sh

# JWT mode — does NOT require the legacy header. Recommended when the
# target has the seeded personas applied (typically: staging).
SMOKE_AUTH_MODE=jwt API=https://<api-host>/v1 bash scripts/smoke.sh
```

`SMOKE_AUTH_MODE=jwt` calls `POST /v1/auth/login` per persona at
startup, caches the bearer tokens, and uses them for the rest of the
run. Same assertions, same exit semantics, no widening of the legacy
auth surface. See
[STAGING_SMOKE.md](STAGING_SMOKE.md) §2 for the full token-flow
description.

Per BETA_READINESS §7, smoke against **production** has three options:

- (a) `SMOKE_AUTH_MODE=jwt` — works if the seeded personas are present
  in production (NOT recommended — they have well-known UUIDs).
- (b) Skip smoke and rely on the §9 persona QA (recommended for
  production-grade Beta — uses real ops-account JWTs).
- (c) Set `ALLOW_X_USER_ID=1` temporarily for a legacy-mode smoke run,
  **then unset it** and roll the pod once more.

If you went with (a): confirm `ALLOW_X_USER_ID` is unset in the rolled
pods before declaring "Beta live."

### Targeted curl checks (auth-aware, safe in prod)

```bash
# Health
curl -sS https://<api-host>/v1/health
# Expect: {"ok":true}

curl -sS -o /dev/null -w "%{http_code}\n" https://<api-host>/v1/health/ready
# Expect: 200

# Login → JWT
TOKEN=$(curl -sS -X POST -H "Content-Type: application/json" \
  -d '{"user_id":"<bootstrap-admin-uuid>"}' \
  https://<api-host>/v1/auth/login | jq -r .access_token)
test -n "$TOKEN" && echo "login ok"

# JWT authenticates /me
curl -sS -H "Authorization: Bearer $TOKEN" https://<api-host>/v1/me | jq .

# Events client diagnostic
curl -sS -H "Authorization: Bearer $TOKEN" \
  https://<api-host>/v1/admin/events-client/status | jq .

# Analytics summary
curl -sS -H "Authorization: Bearer $TOKEN" \
  https://<api-host>/v1/admin/analytics/summary | jq .

# Ops summary
curl -sS -H "Authorization: Bearer $TOKEN" \
  https://<api-host>/v1/admin/ops/summary | jq .
```

Every command above must succeed for a **GO** decision.

---

## 6. Monitoring dashboard checklist

These hooks already exist in the code (see BETA_READINESS §6). Beta
launch day is when you actually wire them into your monitoring stack.

### Probes

- [ ] k8s `livenessProbe` → `GET /v1/health` every 10s. Failure → kill
      pod.
- [ ] k8s `readinessProbe` → `GET /v1/health/ready` every 10s. Failure
      → remove pod from service.
- [ ] Load balancer / reverse proxy health check → `GET /v1/health/ready`.
- [ ] (Optional but recommended) Scrape `GET /v1/health/version` once
      per deploy and log the response. The endpoint returns the build
      metadata (`app_version`, `git_sha`, `build_time`,
      `release_channel`, `node_env`) — useful when triaging "what
      version is running right now?" in incidents.

### Scrape targets (every 60s, alert on threshold)

| Endpoint | Alert on |
|---|---|
| `GET /v1/admin/events-client/status` | `parse_failed > 0` (contract drift); `(timeouts + http_errors) / (parsed_ok + 1) > 0.05` over 5 minutes (upstream incident) |
| `GET /v1/admin/analytics/summary` | `AUTH_LOGIN` count flatlines (auth broken); `POST_CREATED` drops > 80% week-over-week (write path broken) |
| `GET /v1/admin/ops/summary` | `open_reports.count` spike (potential abuse / spam wave) |

The scrape requires a Bearer token. Mint a long-lived JWT for the
monitoring service from the bootstrap admin user; rotate it whenever
`JWT_SECRET` rotates.

### Log aggregation

Forward stdout from every API pod to your log aggregator. Important
patterns:

| Pattern | Severity | Meaning |
|---|---|---|
| `PRISM events search/getById returned HTTP 5..` | warn | Upstream incident |
| `PRISM events search/getById failed (.*)` | warn | Network / timeout / abort |
| `PRISM events ... envelope malformed` | warn | Contract drift |
| `analytics .* failed: .*` | warn | Analytics DB write failed (transient OK; sustained = investigate) |
| `notification\[.*\] delivery had .* failed channel\(s\)` | warn | Email/push provider issue (no-op at Beta if `NOTIFICATION_DELIVERY_MODE=noop`) |
| `Database not reachable` | error | DB connectivity broken; readiness probe should already be failing |

Every response carries an `x-request-id` header (from
`RequestIdMiddleware`). Always include it when triaging user reports.

### Manual dashboards

- [ ] Admin web "Events client" card — open and refresh hourly on
      launch day.
- [ ] Admin web "Analytics (30d)" card — confirm representative event
      types appear after the first wave of usage.

---

## 7. Rollback plan

Rollback decisions are time-sensitive. The triage order:

1. **Is the API process up?** (`/health` returns 200?)
2. **Is the DB reachable?** (`/health/ready` returns 200?)
3. **Are user-facing surfaces responsive?** (`/v1/home` returns < 1s for
   the bootstrap admin?)
4. **Are writes succeeding?** (a manual `POST /v1/rooms/:slug/posts`
   from the bootstrap admin returns 201?)

Map each NO to one of these recovery paths.

### Rollback path A — image-only revert (most common)

The new image has a code regression but the schema is fine.

```bash
# Re-tag the previous known-good image as :current and roll pods.
docker tag prism-club-api:<previous-sha> prism-club-api:current
# Update the platform/Helm/Compose manifest to use :current and apply.
```

No DB action required. `prisma migrate deploy` is idempotent — running
it again on already-migrated DB is a no-op. The previous image still
works against the migrated schema as long as no migration was
**destructive** (drop / alter-column-narrow). The Beta freeze contains
none of those.

Time budget: **5 minutes** including pod readiness.

### Rollback path B — migration revert (rare)

A migration applied successfully but the new code is incompatible with
the schema. Postgres does not support `prisma migrate undo` in
production; the safe path is to restore from snapshot:

1. Stop the API pods (scale to 0) to halt writes.
2. Restore the pre-deploy snapshot to a new DB instance.
3. Repoint `DATABASE_URL` at the restored DB.
4. Re-tag and roll the previous image.
5. Verify with §5 smoke.
6. Once stable, plan a forward-only migration to fix the schema.

Time budget: **30-60 minutes** depending on snapshot restore speed.
Data written between deploy and rollback will be lost — Beta is small
enough that this is acceptable, but communicate it explicitly.

### Rollback path C — secret rotation (emergency)

`JWT_SECRET` or an S3 / PRISM events key leaked.

- `JWT_SECRET`: regenerate (`openssl rand -hex 32`), update the secret
  store, roll the API pods. All issued JWTs become invalid; users
  re-authenticate. Communicate the forced logout in the status page.
- S3 keys: rotate via the cloud console; update `S3_ACCESS_KEY_ID` /
  `S3_SECRET_ACCESS_KEY` in the secret store; roll the API pods. The
  lazy-config in `S3MediaStorage` re-reads env on first upload after
  restart.
- `PRISM_EVENTS_API_KEY`: rotate with the upstream provider; update env;
  roll pods. Until rotation lands, `events-client/status` will show
  rising `http_errors`.

### When NOT to roll back

- A single user reports a bug that doesn't reproduce. Investigate first;
  reach for the rollback only if multiple independent users see it or
  the error rate jumps in §6 dashboards.
- Analytics counts look "low" in the first hour. They WILL be low —
  Beta starts with no traffic. Wait for traffic before judging.
- One event in `PRISM events client` shows `parse_failed = 1`. The
  pipeline is designed to skip bad rows. Alert only on a rising trend.

---

## 8. Incident response basics

### Severity ladder

| Sev | Definition | Response |
|---|---|---|
| **SEV-1** | Full outage (no health probe, no DB) OR auth completely broken (no one can log in) OR data loss in progress | Page on-call immediately; roll back via §7 if root cause not found in 15 minutes |
| **SEV-2** | Major surface broken (Event Detail returns 500, image uploads all fail, admin web unreachable) but the rest of the app works | Page on-call; investigate before rolling; communicate ETA on status page |
| **SEV-3** | Single feature degraded for a subset of users (e.g., a specific Topic Hub renders slowly, one curator's reports fail) | File a ticket; investigate during business hours |
| **SEV-4** | Cosmetic / minor (typo in copy, wrong empty-state message) | Backlog |

### First-hour response (SEV-1 / SEV-2)

1. **Acknowledge** in the on-call channel within 5 minutes.
2. **Status page** updated to "investigating" within 10 minutes.
3. **Capture context** (don't fix yet — capture first):
   - `kubectl logs --tail 200 <api-pod>` or platform equivalent.
   - Failing request ids from user reports (`x-request-id` header).
   - Output of `/v1/admin/events-client/status` and
     `/v1/admin/analytics/summary`.
4. **Identify** — is this a release regression (rolled in the last
   24h) or a runtime issue (upstream, infra)?
5. **Decide** — fix forward or roll back per §7. Default to rolling
   back if no root cause is found in 15 minutes.
6. **Communicate** — status page updates every 30 minutes until
   resolved.
7. **Post-mortem** within 5 business days for SEV-1, optional for
   SEV-2+.

### Comms templates

```
[INVESTIGATING] PRISM Club is investigating reports of <symptom>.
Updates every 30 minutes. — <timestamp>
```

```
[IDENTIFIED] The cause is <component>. We are <fixing forward / rolling
back>. Estimated recovery: <duration>. — <timestamp>
```

```
[RESOLVED] PRISM Club is fully operational. Root cause: <one line>.
Post-mortem to follow. — <timestamp>
```

### Forensics

For every SEV-1 / SEV-2 incident, capture before resolving:

- The exact deploy sha that was running when the incident started.
- The error rate over the incident window (from §6 scrape data).
- Up to 10 representative `x-request-id` values for failing requests.
- Whether `events-client/status` showed any signal change.
- The DB backup id available at the start of the incident.

Store in the incident ticket. Don't rely on memory.

---

## 9. Persona-based QA checklist

Smoke against the deployed environment by walking each persona's
flow once. **Each row must pass.** Detailed steps live in
[BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md); this is just the gate.

### Setup

- [ ] Bootstrap admin can log in via `POST /v1/auth/login` and the
      admin web.
- [ ] At least three additional test accounts exist (member, planner,
      curator/moderator) with appropriate role rows.

> Beta does NOT ship signup. Create test accounts via SQL `INSERT INTO
> users / profiles / user_roles`. Record their UUIDs in the cut-over
> log so they can be reused for post-launch QA.

### Member journey

- [ ] Login → `/home` renders the bundle (followed rooms, recommended
      rooms / events, trending posts, active hubs, recent saves, unread
      notification count).
- [ ] Search returns at least one hit for a seeded query.
- [ ] Topic Hub loads with blocks, signals, related rooms, related
      events.
- [ ] EventCard tap → `/events/:id` Event Detail loads.
- [ ] Room timeline renders. Follow toggle works (UI flips + count
      increments).
- [ ] Post compose → submit text → appears in timeline.
- [ ] Post compose → attach image → upload succeeds → renders in
      timeline.
- [ ] Tap a post author → `/users/:id` profile renders.
- [ ] User-follow toggle works.
- [ ] Report sheet from a post → submit → 201, no error toast.
- [ ] `/me/notifications` shows new notifications when another account
      replies.
- [ ] `/me/saves` shows a saved post / reference / event card.

### Verified Planner journey

- [ ] Planner space unlocked (no lock dialog).
- [ ] Recruitment room loads existing posts with structured fields.
- [ ] RecruitmentComposer submit creates a new post visible in
      timeline + search.
- [ ] Status chip toggle (OPEN → CLOSED → FILLED) works for the
      planner's own posts only.

### Curator + Moderator journey

- [ ] SpaceList shows 검수 큐로 가기 + 운영 대시보드 banners.
- [ ] `/admin/ops` dashboard counters render with non-zero values
      after some QA traffic.
- [ ] `시그널 새로고침` action returns success snackbar.
- [ ] `/admin/reports` shows the report submitted in the Member
      journey.
- [ ] Resolve with HIDE → reported post disappears from at least three
      surfaces (timeline, search, home).
- [ ] `/curate` → APPROVE a pending contribution → block content
      updates + audit snapshot persists.

### Admin web journey

- [ ] Admin web login with the bootstrap admin user succeeds.
- [ ] All eight dashboard cards render (Pending contributions, Open
      reports, Recruitment, Signals, Recent users, Recent rooms, Recent
      posts, Events client, Analytics).
- [ ] Refresh signals button works.
- [ ] Events client card shows `mode: prism` and
      `base_url_configured: true`.
- [ ] Analytics card shows the event types that the QA flow generated.

### Media upload journey

- [ ] `POST /v1/media/images` (multipart, jpg/png/webp/gif, ≤ 5 MB)
      returns 201 with `url` pointing at the configured public base.
- [ ] The returned URL is fetchable in a browser (200, image renders).
- [ ] Verify the object exists in the S3 bucket (cloud console) under
      `<S3_OBJECT_PREFIX>/`.

### PRISM EVENT integration journey

- [ ] `GET /v1/event-cards/:id` for a seeded card returns 200 with
      hero + related rooms + related posts + `default_compose_room_slug`.
- [ ] Submit `GET /v1/events/search?q=<seeded-keyword>` — at least
      one hit; rows look well-formed (no empty title or unparseable
      starts_at).
- [ ] `/admin/events-client/status` shows `parsed_ok > 0` after the
      first search.
- [ ] If `EVENTS_CLIENT_MODE=prism`: temporarily set
      `PRISM_EVENTS_API_BASE_URL` to a non-resolving host, roll one
      pod, repeat the search → expect `http_errors / timeouts`
      incremented; UI renders empty state instead of 500. Revert
      after the check.

### Analytics verification

- [ ] `GET /v1/admin/analytics/summary` returns `window_days: 30` and
      `counts: [...]`.
- [ ] After the Member journey: `AUTH_LOGIN`, `POST_CREATED`,
      `REPLY_CREATED`, `ROOM_FOLLOWED`, `ITEM_SAVED`,
      `NOTIFICATION_READ`, `REPORT_CREATED`, `MEDIA_UPLOADED`,
      `EVENT_DETAIL_VIEWED` all appear with count ≥ 1.
- [ ] Spot-check one row directly:
      ```sql
      SELECT actor_id, event_type, payload, created_at
      FROM analytics_events
      WHERE event_type = 'POST_CREATED'
      ORDER BY created_at DESC LIMIT 1;
      ```
      Payload must NOT contain `body`, `message`, `email`, or any
      free-text content.

---

## 10. Post-launch (T+24h)

- [ ] Status page updated to "Operational" if not already.
- [ ] Review the first 24 hours of monitoring data:
  - error rate trend
  - `events-client/status` cumulative counters
  - top 10 `x-request-id` values for any 5xx responses
- [ ] Confirm the §3 backup ran on schedule overnight.
- [ ] Open a retro doc (or ticket) capturing:
  - what was easy
  - what was harder than expected
  - what we'd change in the runbook for the next cut-over
- [ ] Update this runbook with anything discovered during the launch.

The runbook is a living document. Every cut-over feeds back into it.
