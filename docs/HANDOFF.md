# PRISM Club — Engineer / Operator Handoff

You are being handed a Beta-ready codebase. This document is the single
page that should orient you: what exists, how to run it, how to deploy
it, what to read first, and what to do before the Beta launch window
opens.

If something below conflicts with one of the linked detailed docs,
**the detailed doc wins**. Treat this page as the index, not the truth.

---

## 1. Baseline

| Field | Value |
|---|---|
| Latest commit | `e310869 docs: add beta launch runbook` |
| Status | Beta-ready (M1–M20 + hardening + Beta readiness + launch ops) |
| Primary branch | `main` |
| Verification (last run on baseline) | 158 backend unit · 43 e2e · 53 Flutter widget · admin tsc clean · flutter analyze info-only · flutter build web succeeds |

If `git status` shows any modifications in your working tree before you
start, capture them and confirm with the previous engineer — the
handoff baseline is the commit above, no local diff.

---

## 2. Implemented feature map (M1–M20)

| Milestone | One-line summary |
|---|---|
| M1 | Core vertical slice — Topic Hub → user room → post → 2-depth reply → reaction |
| M2 | Knowledge curation — contributions + curator approval + audit snapshot |
| M3 | Unified search across hubs / blocks / rooms / posts / event cards / references |
| M4 | Planner space + recruitment posts (role / schedule / location / …) |
| M5 | Event detail bundle (`GET /v1/event-cards/:id` + Flutter `EventDetailScreen`) |
| M6 | Retention loop — room follows, saves, notifications |
| M7 | Personalized home (`/v1/home` bundle + `/v1/home/feed` paginated) |
| M8 | User profiles + lightweight social graph (user-follow) |
| M9 | Moderation + reports + audit log + HIDDEN status across read surfaces |
| M10 | Media attachments (local `/uploads/<uuid>.<ext>` baseline) |
| M11 | Ops dashboard inside Flutter app (`GET /v1/admin/ops/summary`) |
| M12 | Activity signals recomputed from real activity |
| M13 | Real auth sessions — JWT via `POST /v1/auth/login` |
| M14 | Deployment readiness — Dockerfile, env-driven CORS / uploads, `/health/ready` |
| M15 | PRISM EVENT integration boundary — `IEventsClient` + mock + real HTTP client |
| M16 | Production media storage — `IMediaStorage` + local + S3 (`@aws-sdk/client-s3`) |
| M17 | Notification delivery adapters — boundary stubs for email / push |
| M18 | Admin web console — Vite + React + TypeScript SPA (`apps/admin/`) |
| M19 | Analytics events pipeline — first-party `analytics_events` table |
| M20 | PRISM EVENT contract hardening — zod schema + per-row skip + diagnostic |

Detailed view: [BETA_READINESS.md](BETA_READINESS.md) §1.

---

## 3. Local run instructions

Prerequisites: Node ≥ 20, Docker Desktop, Flutter ≥ 3.41.

```powershell
# Repo root
npm install
docker compose up -d postgres        # host port 5433
cp .env.example .env                  # then edit if needed
npx prisma migrate dev                # applies every migration on a fresh DB
npm run db:seed                       # six personas + fixtures

# In separate terminals:
npm run api:dev                       # http://localhost:3000/v1
npm run admin:dev                     # http://localhost:5180

# Flutter client (web is fastest):
cd apps/mobile
flutter pub get
flutter run -d chrome
```

Apply migrations to the **test** database once (only needed before
`npm run api:test:e2e` for the first time):

```powershell
$env:DATABASE_URL = "postgresql://prism:prism@localhost:5433/prism_club_test?schema=public"
npx prisma migrate deploy
Remove-Item Env:DATABASE_URL
```

> **Windows note:** A Windows-installed PostgreSQL on port 5432 shadows
> the Docker container. Compose maps host **5433** → container 5432.

---

## 4. Test commands

```bash
# Backend
npm run api:test          # 158 unit tests, 22 suites
npm run api:test:e2e      # 43 e2e tests, 15 suites

# Admin web (typecheck — UI is exercised manually)
npm run admin:typecheck

# Flutter
cd apps/mobile
flutter analyze           # info-only output expected, no errors / warnings
flutter test              # 53 widget tests
flutter build web --no-tree-shake-icons

# End-to-end smoke (requires running API + seeded DB)
bash scripts/smoke.sh
```

All of the above must pass on the baseline commit. If any one fails on
a fresh clone, that is your first ticket.

---

## 5. Deployment sequence (summary)

The full procedure is in [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md).
At handoff time the high-level shape is:

```
T-72h ─── pre-launch checklist (runbook §1)
T-30m ─── DB backup snapshot + migration dry-run (runbook §3)
T-0   ─── apply migrations + roll API pods (runbook §4)
T+5m  ─── smoke + per-persona QA (runbook §5 + §9, QA script)
T+20m ─── status page → "Beta live"
```

Container build: `docker build -t prism-club-api:<sha> -f apps/api/Dockerfile .`
Migration step: `DATABASE_URL=… npx prisma migrate deploy` — runs BEFORE
the new image is rolled. The image does not run migrations on boot.

Env matrix lives in [DEPLOYMENT.md](DEPLOYMENT.md) §2 and is also
duplicated in [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) §2
sorted by risk.

---

## 6. Which docs to read, in which order

If you are picking this up cold, the recommended reading path is:

1. **This file** (HANDOFF.md) — high-level orientation. ~10 min.
2. **README.md** — repo layout, scripts, architecture decisions. ~10 min.
3. **[BETA_READINESS.md](BETA_READINESS.md)** — feature map, architecture
   snapshot, persona walkthrough, monitoring hooks, go/no-go. ~25 min.
4. **[DEPLOYMENT.md](DEPLOYMENT.md)** — env matrix + container build
   + Flutter / admin web build. ~15 min.
5. **[BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md)** — execution-time
   guide. Read once before launch day, keep open during cut-over. ~30 min.
6. **[BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md)** — manual QA flows. Skim
   before launch day; execute during cut-over. ~15 min skim.
7. **[STAGING_BRINGUP_CHECKLIST.md](STAGING_BRINGUP_CHECKLIST.md)** —
   the exact single-page checklist for first-time staging stand-up.
   Run this immediately before the cutover rehearsal. ~30 min to
   execute end-to-end.
8. **[CUTOVER_REHEARSAL.md](CUTOVER_REHEARSAL.md)** — the staging
   dry-run of the production cut-over. Read once before scheduling the
   rehearsal; execute against staging at least 3 business days before
   the real launch. ~15 min read, ~120 min to execute. *Required before
   the production cut-over.*
9. **[EVENTS_INTEGRATION.md](EVENTS_INTEGRATION.md)** — upstream events
   contract + failure matrix. Read if you are flipping
   `EVENTS_CLIENT_MODE=prism`. ~10 min.
10. **[ANALYTICS.md](ANALYTICS.md)** — first-party event taxonomy and
    privacy rules. Read if you are touching the analytics surfaces. ~10 min.
11. **[NEXT_BACKLOG.md](NEXT_BACKLOG.md)** — what is intentionally still
    deferred. Read to understand what you should NOT promise. ~10 min.
12. **[ALPHA_RC_CHECKLIST.md](ALPHA_RC_CHECKLIST.md)** — historical Alpha
    RC view. Read only if you need the M1–M12 + hardening provenance. Optional.

Planning context (deep background, not load-bearing for the cut-over):
docs/00_PRISM_CLUB_BRIEF.md through docs/05_ROADMAP.md.

---

## 7. Known limitations at handoff

These are intentional. Do not surprise stakeholders by promising fixes
mid-Beta — each one is tracked in
[NEXT_BACKLOG.md](NEXT_BACKLOG.md).

| Area | Limitation |
|---|---|
| Auth | Passwordless login (any seeded / provisioned user id works). No signup / email verification / password reset / OAuth. |
| Notification delivery | `email` / `push` boundaries are stubs. Default is `noop` (IN_APP only). |
| Analytics | 30-day rollup endpoint only. No exporter, no retention job. Table grows monotonically. |
| Media | No antivirus, no resize pipeline, no CDN. `local` mode does not survive container restarts. |
| Search | ILIKE substring — no Korean tokenizer, no BM25, no vector / semantic. |
| Moderation HIDE | Works for POST / REPLY. ROOM / USER / REFERENCE hide is audit-only. |
| Rate limiting | None at the API edge. |
| Observability | Request-id middleware only; no log ship, no metrics, no tracing. |
| Profiles | No avatar upload, no nickname rename. |
| Logout | Stateless JWT — `POST /v1/auth/logout` is a no-op stub; client drops the token. |

---

## 8. Operational responsibilities

### Before launch

- Read §6 in order through item 6 (runbook).
- Run the verification suite once on the baseline commit and confirm
  every test count matches §4 expectations.
- Take inventory of secrets you will need: `JWT_SECRET`,
  `DATABASE_URL`, `S3_*`, optionally `PRISM_EVENTS_API_KEY`. Generate
  fresh values in your secret store before launch day, NOT during.
- Bootstrap at least one CURATOR / MODERATOR / ADMIN account in the
  target DB (see runbook §1 Identity bootstrap). The seed personas are
  dev-only.
- Wire monitoring hooks (runbook §6): liveness / readiness probes plus
  scrape of `/v1/admin/events-client/status` and
  `/v1/admin/analytics/summary`.

### During launch (cut-over window)

- Follow [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) §4 timeline.
- Pair with the on-call partner. The runbook is written assuming two
  humans in the loop.
- Run [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md) §1–§7 in order. Section §7
  (analytics) verifies events that §1–§6 generate; do not skip ahead.
- If anything in the smoke or QA fails, default to the rollback paths
  in runbook §7 rather than fixing forward.

### After launch (24h-72h)

- Watch `/v1/admin/events-client/status` and the admin web "Events
  client" card. `parse_failed > 0` means upstream contract drift —
  triage with whoever owns the upstream API.
- Watch `/v1/admin/ops/summary` daily for `open_reports.count` spikes.
- Confirm overnight backups ran on schedule.
- Open the retro doc per runbook §10.

### Ongoing (for every deploy)

- `prisma migrate deploy` BEFORE rolling the new image. Never the
  other way around.
- Never set `ALLOW_X_USER_ID=1` in production except during the smoke
  cut-over window — and unset it immediately after.
- Never log or commit `JWT_SECRET`, `DATABASE_URL`,
  `PRISM_EVENTS_API_KEY`, or `S3_*` values.
- Migrations are reviewed BEFORE merge to `main`. A migration in a PR
  that has not been reviewed gates the deploy.

---

## 9. Immediate next actions before launch

Treat this list as the "Day 1 on the job" todo. None of these require
code changes.

- [ ] Clone the repo at commit `e310869`. Run §3 local run + §4 tests.
      Confirm everything is green.
- [ ] Read §6 items 1–6 in order. Reach out to the previous engineer
      with any clarifying questions while they are still in scope.
- [ ] Provision the Beta environment: managed Postgres, container
      registry, static hosts for Flutter web + admin web, S3-compatible
      bucket, DNS + TLS for the two hostnames. Reuse organization-
      standard tooling — none of these are project-specific.
- [ ] Mint the launch-day secrets in your secret store. Do NOT commit
      them anywhere.
- [ ] Bootstrap the first ADMIN user in the target DB. Record the UUID
      in your ops vault.
- [ ] Wire the four monitoring probes / scrapes from runbook §6 into
      your monitoring stack.
- [ ] Schedule the cut-over window with stakeholders. Block at least
      90 minutes plus a 1-hour post-launch monitoring window.
- [ ] Walk the runbook with the on-call partner who will shadow you
      on launch day. Confirm they have read it too.
- [ ] Tag the baseline commit (`git tag beta-rc-1 e310869`) so rollback
      §7A has a stable target.

When all boxes above are checked you are ready to execute the launch
window per [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md).
