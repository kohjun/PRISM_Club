# PRISM Club — Beta Readiness

This document is the freeze point between **Alpha RC** (M1–M12 +
hardening) and **Beta**. Beta is the first build we are willing to put in
front of real users with a real domain, a real database, and a real
upstream Events service. It does NOT yet mean general availability or
production scale — see §4 *Production readiness* and §7 *Go / no-go*.

> **Companion docs**
> - [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) — deploy sequence, env / migration / rollback / incident response / monitoring
> - [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md) — persona-by-persona manual QA flows for cut-over
> - [ALPHA_RC_CHECKLIST.md](ALPHA_RC_CHECKLIST.md) — historical Alpha RC view
> - [DEPLOYMENT.md](DEPLOYMENT.md) — env matrix + container + Flutter web build
> - [EVENTS_INTEGRATION.md](EVENTS_INTEGRATION.md) — upstream events boundary
> - [ANALYTICS.md](ANALYTICS.md) — first-party event taxonomy
> - [NEXT_BACKLOG.md](NEXT_BACKLOG.md) — what is intentionally still deferred

---

## 1. Feature map (M1–M20)

| Milestone | Surface | Status |
|---|---|---|
| M1 | Core vertical slice — Topic Hub → user room → post → 2-depth reply → reaction | ✅ |
| M2 | Knowledge curation — contributions + curator approval + audit snapshot | ✅ |
| M3 | Unified search across hubs / blocks / rooms / posts / event cards / references | ✅ |
| M4 | Planner space + recruitment posts (role/schedule/location/...) | ✅ |
| M5 | Event detail bundle (`GET /v1/event-cards/:id` + Flutter `EventDetailScreen`) | ✅ |
| M6 | Retention loop — room follows, saves, notifications | ✅ |
| M7 | Personalized home (`/v1/home` bundle + `/v1/home/feed` paginated) | ✅ |
| M8 | User profiles + lightweight social graph (user-follow) | ✅ |
| M9 | Moderation + reports + audit log + HIDDEN status across read surfaces | ✅ |
| M10 | Media attachments (local `/uploads/<uuid>.<ext>` baseline) | ✅ |
| M11 | Ops dashboard inside Flutter app (`GET /v1/admin/ops/summary`) | ✅ |
| M12 | Activity signals recomputed from real activity (`POST /v1/admin/signals/refresh`) | ✅ |
| M13 | Real auth sessions — JWT via `POST /v1/auth/login`; legacy `X-User-Id` non-prod only | ✅ |
| M14 | Deployment readiness — multi-stage Dockerfile, env-driven CORS / uploads, `/health/ready` probe | ✅ |
| M15 | PRISM EVENT integration boundary — `IEventsClient` + mock + real HTTP client | ✅ |
| M16 | Production media storage — `IMediaStorage` + local + S3 (`@aws-sdk/client-s3`) | ✅ |
| M17 | Notification delivery adapters — `INotificationDeliverer` + noop / email / push boundaries | ✅ |
| M18 | Admin web console — Vite + React + TypeScript SPA (`apps/admin/`) | ✅ |
| M19 | Analytics events pipeline — first-party `analytics_events` table + admin summary | ✅ |
| M20 | PRISM EVENT contract hardening — zod schema + per-row skip + diagnostic counters | ✅ |

---

## 2. Architecture snapshot

```
┌─────────────────────────┐        ┌─────────────────────────┐
│ Flutter app             │        │ Admin web (Vite + React)│
│ apps/mobile/            │        │ apps/admin/             │
│   /home shell (5 tabs)  │        │   ops / reports /       │
│   profile / curation /  │        │   signals / events      │
│   moderation / events…  │        │   client / analytics    │
└──────────┬──────────────┘        └──────────┬──────────────┘
           │  Bearer JWT (M13)                │
           ▼                                   ▼
┌──────────────────────────────────────────────────────────────┐
│ apps/api  (NestJS modular monolith, /v1 prefix)              │
│                                                              │
│  shared/        AuthGuard (JWT + X-User-Id fallback),        │
│                 RolesGuard, AccessControlService,            │
│                 RequestIdMiddleware, AllExceptionsFilter     │
│                                                              │
│  modules/                                                    │
│    auth, users, community, knowledge, event-link,            │
│    reference, posts, search, event-detail, notifications,    │
│    follows, saves, home, user-profile, moderation, media,    │
│    ops, signals, analytics, health                           │
│                                                              │
│  Boundary tokens (Symbol-based DI):                          │
│    EVENTS_CLIENT     → MockEventsClient | PrismEventsClient  │
│    MEDIA_STORAGE     → LocalMediaStorage | S3MediaStorage    │
│    NOTIFICATION_DELIVERY → LocalNoop | Email | Push          │
└─────────┬──────────────────────────┬────────────────────────┘
          │ Prisma 5                 │ HTTP (zod-validated)
          ▼                          ▼
┌──────────────────────┐    ┌────────────────────────────┐
│ PostgreSQL 16        │    │ PRISM EVENT / CONTENIDO    │
│   prism_club         │    │   GET {BASE}/events?q=…    │
│   prism_club_test    │    │   GET {BASE}/events/:id    │
│   analytics_events   │    └────────────────────────────┘
└──────────────────────┘
```

**Key boundaries (each one swappable at boot via env):**

- `EVENTS_CLIENT_MODE` ∈ {`mock`, `prism`}
- `MEDIA_STORAGE_MODE` ∈ {`local`, `s3`}
- `NOTIFICATION_DELIVERY_MODE` ∈ {`noop`, `email`, `push`}

**Test surface (verified for Beta freeze):**

- `npm run api:test` — 158 unit tests, 22 suites
- `npm run api:test:e2e` — 43 e2e tests, 15 suites
- `npm run admin:typecheck` — clean
- `flutter analyze` — 6 info-only items, no errors / warnings
- `flutter test` — 53 widget tests
- `flutter build web --no-tree-shake-icons` — succeeds

`scripts/smoke.sh` (~77 curl-driven checks across M1–M13 + M19) requires
a running API + seeded DB; not part of the headless verification suite
but documented as the manual end-to-end check.

---

## 3. Demo walkthrough by persona

> For the **operational** version of this walkthrough — concrete tap
> targets, expected results, curl checks, and per-step failure modes —
> see [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md). The summary below is the
> elevator pitch; the QA script is what to run during cut-over.

All six personas are seeded by `npm run db:seed`. The dev login picker
shows their nicknames; each `POST /v1/auth/login` exchanges the user id
for a JWT that the Flutter app + admin web both store in client-side
storage and send as `Authorization: Bearer …`.

### Member — **minseo** (민서) / **joon**

1. `/home` lands on the personalized feed (followed-room updates,
   recommended rooms, recommended events, trending posts, active hubs,
   recent saves, unread notification count).
2. **검색** tab — try "후기" / "swap" / "환승연애". Empty state offers
   popular topic chips.
3. **커뮤니티** tab — browse spaces. Member sees 참가자 unlocked, 기획자
   locked (lock dialog explains why).
4. Open 연애 콘텐츠 → category → Topic Hub: blocks + signals + related
   rooms + related events. Tap a related event → `/events/:cardId` Event
   Detail with hero + related rooms + related posts.
5. Tap a related room → timeline. Tap 팔로우. Tap a post author avatar
   → `/users/:id` profile. Tap 팔로우 there to user-follow.
6. From a post detail, `⋯` → 신고 (Report sheet).
7. **알림** tab — seeded notifications (REPLY_ON_POST, etc.). Tap one
   → marked read.
8. **저장** tab — saved POST / REFERENCE items, filter chip by type.

### Verified Planner — **studio_lead** / **studio_mate**

1. **커뮤니티** tab — 기획자 스튜디오 is unlocked.
2. Category → Topic Hub → **스태프 모집 공고** room. Three seeded
   recruitment posts (2 OPEN, 1 CLOSED). Each renders the structured
   `RecruitmentPostCard` (role / schedule / location / compensation /
   capacity / application method).
3. FAB → **모집 글쓰기** opens the RecruitmentComposer. Submitted post
   appears in the timeline and in search (for verified planners only).
4. Author-only status chip flips OPEN ↔ CLOSED ↔ FILLED.

### Curator + Moderator — **coral**

1. SpaceList shows **검수 큐로 가기** + **운영 대시보드** banners.
2. **운영 대시보드** → counters (pending contributions, open reports,
   recruitment open / total, recent users / rooms / posts). Cards
   deep-link to `/curate`, `/admin/reports`, etc.
3. AppBar **시그널 새로고침** action → `POST /v1/admin/signals/refresh`
   → snackbar.
4. `/admin/reports` → open report → resolve with HIDE / RESTORE /
   DISMISS + optional moderator note. HIDDEN posts disappear from
   timelines, search, home, profile activity, and saves.
5. `/curate` → pending knowledge contribution → APPROVE → block content
   updated + audit snapshot captured.

### Admin web (CURATOR / MODERATOR / ADMIN)

1. `npm run admin:dev` → `http://localhost:5180`.
2. Log in as coral with the seeded user id.
3. Dashboard cards: Pending contributions, Open reports, Recruitment
   open/total, Signals (with refresh button), Recent users, Recent rooms,
   Recent posts (full width), **Events client** (mode / base URL /
   parsed_ok / parse_failed / http_errors / timeouts), **Analytics
   (30d)** (event-type rollup).

---

## 4. Production readiness checklist

### Required before Beta launch (gating)

- [ ] `JWT_SECRET` set to a freshly generated long random value.
- [ ] `NODE_ENV=production` everywhere except dev / staging.
- [ ] `ALLOW_X_USER_ID` **unset** in production (legacy header rejected).
- [ ] `CORS_ORIGINS` set to an explicit allowlist (no `*`).
- [ ] `DATABASE_URL` points at managed Postgres with backups +
      point-in-time recovery.
- [ ] `npx prisma migrate deploy` runs against the target DB before each
      rolling deploy.
- [ ] HTTPS terminates at the reverse proxy / load balancer (not in the
      API).
- [ ] Container readiness probe wired to `GET /v1/health/ready` (returns
      503 when DB is unreachable).
- [ ] Container liveness probe wired to `GET /v1/health` (always 200 if
      the process is up).
- [ ] At least one CURATOR / MODERATOR / ADMIN account exists in the
      target DB (the seed personas are dev-only).

### Recommended before Beta launch

- [ ] `EVENTS_CLIENT_MODE=prism` + `PRISM_EVENTS_API_BASE_URL` set so
      Event Detail surfaces use the real upstream. Monitor the
      `/v1/admin/events-client/status` endpoint for `parse_failed > 0`
      (contract drift) and `http_errors / timeouts > 0` (upstream
      incidents).
- [ ] `MEDIA_STORAGE_MODE=s3` + `S3_*` envs + `MEDIA_PUBLIC_BASE_URL`
      configured. The local fallback is **not** safe across container
      restarts or horizontal scale.
- [ ] `NOTIFICATION_DELIVERY_MODE` left at `noop` until a real provider
      lands (see [NEXT_BACKLOG](NEXT_BACKLOG.md) §2). The boundary will
      accept `email` / `push` once you flip it.
- [ ] Flutter web bundle built with the production
      `--dart-define=API_BASE_URL=https://api.club.example.com/v1`.
- [ ] Admin web bundle built with
      `VITE_API_BASE_URL=https://api.club.example.com/v1` and served
      from a separate origin (so `CORS_ORIGINS` can include both).
- [ ] Smoke run (`scripts/smoke.sh`) against the deployed environment
      with `API=` overridden — note that smoke uses `X-User-Id`, which
      only works while `ALLOW_X_USER_ID=1`. Use it once during cut-over,
      then drop the env flag.

### Out of scope for Beta (deferred — see NEXT_BACKLOG.md)

- Real auth (email/password, OAuth, signup, email verification, password
  reset).
- Email / push provider wiring (the boundary is ready; no provider yet).
- Analytics warehouse export + retention job.
- Image antivirus + resize pipeline + CDN.
- Rate limiting at the API edge.
- Centralized logging, metrics, tracing.
- Real-time updates (WebSocket / SSE).
- ROOM / USER / REFERENCE hide visibility flip.
- Native mobile distribution (App Store / Play).

---

## 5. Known limitations at Beta

| Area | Limitation | Tracked in |
|---|---|---|
| Auth | Passwordless login (any seeded user id works). | NEXT_BACKLOG §1 |
| Notifications | IN_APP only — `email` / `push` deliverers are stubs. | NEXT_BACKLOG §2 |
| Analytics | 30-day rollup only. No exporter, no retention. | NEXT_BACKLOG §3 |
| Media | No antivirus, no resize pipeline, no CDN. | NEXT_BACKLOG §4 |
| Search | ILIKE substring — no Korean tokenizer / BM25 / vector. | NEXT_BACKLOG §6 |
| Moderation | HIDE works for POST / REPLY; ROOM / USER / REFERENCE hide is audit-only. | NEXT_BACKLOG §6 |
| Rate limiting | None at the API edge. | NEXT_BACKLOG §6 |
| Observability | Request-id middleware only; no log ship, no metrics, no tracing. | NEXT_BACKLOG §6 |
| Profiles | No avatar upload, no nickname rename. | NEXT_BACKLOG §6 |
| Logout | Stateless JWT — `POST /v1/auth/logout` is a no-op stub; client drops the token. | NEXT_BACKLOG §6 |

---

## 6. Monitoring hooks

The codebase exposes the following surfaces operators should wire into
their monitoring stack. None of these require new code:

| Hook | What it tells you | How to consume |
|---|---|---|
| `GET /v1/health` | Process is alive | k8s liveness probe |
| `GET /v1/health/ready` | DB is reachable (`SELECT 1`) | k8s readiness probe; load balancer health check |
| `GET /v1/admin/events-client/status` | `parsed_ok / parse_failed / http_errors / timeouts / last_error` for the upstream PRISM EVENT client (M20) | Scrape every 60s into Datadog / Grafana / CloudWatch. Alert when `parse_failed > 0` (contract drift) or `timeouts / http_errors` rises above baseline. |
| `GET /v1/admin/analytics/summary` | 30-day event-type rollup | Sanity check during incidents (e.g., POST_CREATED suddenly drops to 0). |
| `GET /v1/admin/ops/summary` | Pending contributions, open reports, recruitment counts, recent users / rooms / posts | Daily ops review; alert on `open_reports.count` spike. |
| `RequestIdMiddleware` | Tags every response with `x-request-id` | Forward to your log aggregator; cross-reference user-reported issues. |
| `AnalyticsService` warn log | `analytics <EVENT_TYPE> failed: …` | The DB write failed but the business transaction succeeded — usually transient. Alert on sustained rate. |
| `PrismEventsClient` warn log | `PRISM events search/getById returned HTTP …` / `failed …` | Upstream incident. Cross-check with `/admin/events-client/status`. |
| `NotificationService` warn log | `notification[…] delivery had N failed channel(s)` | Channel-specific provider issue once delivery providers are wired. |

All ops endpoints require `CURATOR / MODERATOR / ADMIN` and respond
identically to the admin web console; operators can dual-use the console
or scrape the JSON directly.

---

## 7. Go / no-go checklist

Run this list against the target environment immediately before tagging
the Beta release. For the launch-day execution flow (deploy sequence,
rollback, incident response) see
[BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md).

### Code freeze

- [ ] `git status` clean on the release branch.
- [ ] `git log` — last commit is `chore: prepare beta readiness` (or
      later non-feature commits).
- [ ] No pending PRs touching schema / migrations / breaking endpoints.

### Headless verification (every PR + the freeze candidate)

- [ ] `npm install` succeeds at repo root.
- [ ] `npm run api:test` — **158 / 158** green.
- [ ] `npm run api:test:e2e` — **43 / 43** green.
- [ ] `npx tsc --noEmit -p apps/api/tsconfig.json` — exits 0.
- [ ] `npx tsc --noEmit -p apps/admin/tsconfig.json` — exits 0.
- [ ] `cd apps/mobile && flutter analyze` — no errors / warnings
      (info-only output OK; 6 known info items as of the freeze).
- [ ] `cd apps/mobile && flutter test` — **53 / 53** green.
- [ ] `cd apps/mobile && flutter build web --no-tree-shake-icons` —
      succeeds.

### Manual smoke (against the deployed target)

- [ ] `bash scripts/smoke.sh` with `API=https://api.example.com/v1` —
      all sections pass (requires `ALLOW_X_USER_ID=1` during cut-over).
- [ ] Each of the six seeded personas signs in via the dev login picker
      (or the deployed equivalent of `POST /v1/auth/login`).
- [ ] Member journey end-to-end (see §3): home → search → community →
      Topic Hub → Event Detail → Room → Profile → Report → 알림 → 저장.
- [ ] Verified planner sees recruitment room + can submit a recruitment
      post.
- [ ] Curator sees both 검수 큐 + 운영 대시보드 banners; can resolve a
      report and approve a contribution.
- [ ] Image upload works (compose a post with an image attachment) and
      renders on the timeline.
- [ ] `POST /v1/auth/login` returns a JWT that authenticates `GET /v1/me`
      via `Authorization: Bearer …`.
- [ ] `GET /v1/admin/events-client/status` returns the expected mode
      (`prism` if `EVENTS_CLIENT_MODE=prism`) and `parse_failed = 0`.

### Operational

- [ ] Database backup verified within the last 24 hours.
- [ ] Rollback path documented (revert image tag + re-apply previous
      migrations if any).
- [ ] On-call rotation aware of Beta cut-over and the monitoring hooks
      in §6.

If every box is checked, **GO**. Otherwise, **NO-GO** — fix and re-run.
