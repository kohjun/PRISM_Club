# PRISM Club — Alpha RC Checklist

This document is the single source of truth for what PRISM Club looks like
at Alpha Release Candidate (post-M12 + hardening). It describes what is
working, what is intentionally deferred, and how to run the full flow
end to end.

---

## 1. Feature map (M1–M20)

| Milestone | Surface | What's working |
|---|---|---|
| M1 | Core slice | Topic Hub, user rooms, posts (text + EventCard + Reference attachments), 2-depth replies, likes |
| M2 | Knowledge curation | Members propose contributions (edit / new block) with optional evidence; curator approve / reject / changes; audit snapshot on approve |
| M3 | Unified search | ILIKE-based search across Topic Hub / blocks / rooms / posts / event cards / references; popular-topic suggestions; access-policy filter |
| M4 | Planner community | `Space.access_policy` (PUBLIC / PLANNER_ONLY); planner space gated to VERIFIED_PLANNER/ADMIN; recruitment posts with role/schedule/location/compensation/capacity/application_method/status |
| M5 | Event detail | `GET /v1/event-cards/:id` returns hero card + related rooms + related posts + default_compose_room_slug; `/events/:cardId` Flutter screen |
| M6 | Retention loop | Room follow, save items (POST/REFERENCE/EVENT_CARD), notifications with spaceAccessPolicy filtering; `Post.bookmarkCount` activated |
| M7 | Personalized home | `GET /v1/home` bundle + `GET /v1/home/feed` paginated; deterministic scoring; 5-tab `HomeShellScreen` |
| M8 | User profiles + follows | Public profile bundle + edit + user-follow distinct from room-follow; role badges; author taps everywhere |
| M9 | Moderation + reports | Report + ModerationAction tables; report → queue → resolve (HIDE/RESTORE/DISMISS); HIDDEN status propagates to all read surfaces |
| M10 | Media attachments | Local image upload (`/uploads/<uuid>.<ext>`); IMAGE attachment_type; composer image picker + thumbnails |
| M11 | Ops dashboard | `GET /v1/admin/ops/summary` (role-gated); Flutter `OpsDashboardScreen` with deep-link cards |
| M12 | Activity signals | Computed TopicSignal entries (HOT_DEBATE / POPULAR_REF / VERIFIED_REVIEWS) recalculated from real activity via `POST /v1/admin/signals/refresh` |
| M13 | Real auth sessions | JWT-backed login: `POST /v1/auth/login`, `GET /v1/auth/session`, `POST /v1/auth/logout`. AuthGuard accepts `Authorization: Bearer <jwt>`; legacy `X-User-Id` still works in non-production for tests/smoke. Flutter persists the access token and sends it automatically. |
| M14 | Deployment readiness | Multi-stage API Dockerfile, env-driven CORS_ORIGINS + UPLOADS_DIR, real `/v1/health/ready` probe, root `build`/`start:prod`/`prisma:migrate:deploy` scripts, `docs/DEPLOYMENT.md`. |
| M15 | PRISM EVENT integration boundary | `EVENTS_CLIENT_MODE=mock` (default; bundled fixture) OR `prism` (real HTTP client at `PRISM_EVENTS_API_BASE_URL`, optional `PRISM_EVENTS_API_KEY`, `PRISM_EVENTS_TIMEOUT_MS`). Failures degrade gracefully: search returns `[]`, getById returns `null`. Local `EventCard` remains the canonical snapshot. `docs/EVENTS_INTEGRATION.md`. |
| M16 | Production media storage | `MEDIA_STORAGE_MODE=local` (default; filesystem under `UPLOADS_DIR`) OR `s3` (`@aws-sdk/client-s3` against AWS S3 / Cloudflare R2 / MinIO via `S3_BUCKET` + `S3_REGION` + `S3_ACCESS_KEY_ID` + `S3_SECRET_ACCESS_KEY` + optional `S3_ENDPOINT`/`S3_FORCE_PATH_STYLE`). Lazy config validation on first upload. |
| M17 | Notification delivery adapters | `NOTIFICATION_DELIVERY_MODE=noop` (default; IN_APP only) OR `email`/`push` boundary stubs. Fire-and-forget; providers MUST NOT throw, they return `DeliveryAttempt[]`. |
| M18 | Admin web console | Vite + React + TypeScript SPA at `apps/admin/`. Authenticates via `POST /v1/auth/login`, persists JWT in localStorage, renders ops summary + open-report queue + signal refresh. Role-gated to CURATOR/MODERATOR/ADMIN on both sides. `npm run admin:dev` (port 5180). |
| M19 | Analytics events pipeline | First-party `analytics_events` table. 11 event types captured server-side fire-and-forget (AUTH_LOGIN, POST_CREATED, REPLY_CREATED, ROOM_FOLLOWED/UNFOLLOWED, ITEM_SAVED/UNSAVED, NOTIFICATION_READ, REPORT_CREATED, MEDIA_UPLOADED, EVENT_DETAIL_VIEWED). Payload scrubber drops PII/body keys + truncates strings. Admin-only `GET /v1/admin/analytics/summary` returns 30-day counts grouped by event_type. `docs/ANALYTICS.md`. |
| M20 | PRISM EVENT contract hardening | `PrismEventsClient` validates upstream payloads with a **zod** `PrismEventDTOSchema` row by row. Malformed rows are skipped and counted as `parse_failed`; valid neighbours still come through. Cumulative `parsed_ok / parse_failed / http_errors / timeouts / last_error` counters surface via `GET /v1/admin/events-client/status` (role-gated) and a new "Events client" card in the admin web console. `docs/EVENTS_INTEGRATION.md` updated with schema + failure-matrix + observability sections. |

---

## 2. Demo walkthrough

Personas (all seeded):

- **minseo** — 민서 — MEMBER
- **joon** — MEMBER
- **haneul** — MEMBER
- **coral** — CURATOR + MODERATOR
- **studio_lead** — VERIFIED_PLANNER
- **studio_mate** — VERIFIED_PLANNER

### Member journey (login as minseo)

1. `/home` lands on the personalized feed: followed-room updates, recommended rooms, recommended events, trending posts, active hubs, recent saves.
2. Bottom nav → **검색** to try unified search (e.g. "후기" or "swap").
3. Bottom nav → **커뮤니티** to browse spaces. Tap "연애 콘텐츠" → category list → Topic Hub.
4. Topic Hub shows blocks + signals + related rooms + related events. Tap a related event tile → `/events/:cardId` Event Detail with hero + related rooms + related posts.
5. Tap a related room → timeline. Tap **팔로우** in AppBar. Tap a post author avatar → `/users/:id` profile.
6. From profile, tap **팔로우** to user-follow. Self-profile shows `⋯` → 프로필 편집 sheet.
7. Bottom nav → **알림** to see seeded notifications.
8. Bottom nav → **저장** to see saved POST / REFERENCE items.
9. From any post detail, `⋯` (when wired) → report sheet sends a Report.

### Curator + Moderator journey (login as coral)

1. SpaceList shows **검수 큐로 가기** banner + **운영 대시보드** banner.
2. **운영 대시보드** → counters (pending contributions, open reports, recruitment open/total, recent users); deep-link to `/curate`, `/admin/reports`, recent users/rooms/posts.
3. **시그널 새로고침** AppBar action → recomputes TopicSignal entries.
4. `/admin/reports` → click a report → resolve with HIDE / RESTORE / DISMISS, optional moderator note. Hidden posts disappear from timelines, search, home, profile.
5. `/curate` → review pending knowledge contributions; approve → snapshot is captured.

### Verified Planner journey (login as studio_lead)

1. Bottom nav → **커뮤니티** → "기획자 스튜디오" space now unlocked.
2. Recruitment room → tap FAB → recruitment composer (role/schedule/etc).
3. Existing recruitment posts visible with status chip + toggle (OPEN/CLOSED/FILLED).
4. Member viewers see no PLANNER_ONLY content anywhere (search, home, profile activity).

---

## 3. Fresh-start flow

From a clean clone on a developer machine:

```powershell
# Repo root: install workspace deps
npm install

# Start Postgres (port 5433 to avoid local conflict)
docker compose up -d postgres

# Wait a few seconds for the container to be ready, then:
cp .env.example .env       # (or copy in your shell)
npx prisma migrate dev      # applies all M1–M20 migrations
npm run db:seed             # seeds 6 personas + spaces/categories/rooms/posts/etc.

# Apply migrations to the test database (used by e2e tests):
$env:DATABASE_URL_TEST | Set-Content -NoNewline ".env.tmp" ; <# windows note #>
# Or simply (cross-platform):
DATABASE_URL="postgresql://prism:prism@localhost:5433/prism_club_test?schema=public" npx prisma migrate deploy

# Run the API on http://localhost:3000/v1
npm run api:dev

# In a separate terminal — Flutter web (Chrome):
cd apps/mobile
flutter pub get
flutter run -d chrome
```

The mobile app starts at the login picker; pick any persona to enter.

---

## 4. Full test commands

```powershell
# Backend unit tests (Jest, ts-jest)
cd apps/api ; npm test

# Backend e2e tests (supertest against the running test DB)
cd apps/api ; npm run test:e2e

# Flutter analyze + tests + web build
cd apps/mobile ; flutter analyze
cd apps/mobile ; flutter test
cd apps/mobile ; flutter build web --no-tree-shake-icons

# End-to-end smoke (requires running API on :3000 and seeded DB)
bash scripts/smoke.sh
```

Expected counts at Alpha RC (post-M20 baseline used for Beta):
- 158 backend unit tests, 22 suites — all green
- 43 backend e2e tests, 15 suites — all green
- 53 Flutter widget tests — all green
- Smoke: ~77 curl-driven assertions covering M1–M13 + M19 sections

---

## 5. Known limitations (Alpha)

Things that are intentionally NOT yet production-shaped:

| Area | Limitation |
|---|---|
| **Auth** | M13 added real JWT sessions and a working `/auth/login` flow. Login is **still passwordless** (any seeded user id signs you in) — production needs email/password or SSO before exposing this to real users. `X-User-Id` remains as a fallback only when `NODE_ENV != production` or `ALLOW_X_USER_ID=1`. |
| **Media storage** | Files land in `apps/api/uploads/` on the API host. No S3, no CDN, no antivirus, no resize pipeline. |
| **Events client** | The boundary is in place (`EVENTS_CLIENT_MODE=prism` activates a real HTTP client). The upstream PRISM EVENT / CONTENIDO API contract is not finalized yet — `mock` mode remains the default for dev/test/demo. |
| **Notifications** | In-app only. No push, no email, no SMS, no realtime channel. |
| **Search** | ILIKE on Postgres. No vector search, no relevance tuning, no synonym handling, no Korean morphological analysis. |
| **Moderation hide** | Hide is implemented for POST and REPLY. ROOM / USER / REFERENCE hide is recorded as an audit row but doesn't yet flip any visibility flag. |
| **Account settings** | No password change, no avatar upload, no nickname rename, no account deletion, no email verification. |
| **Deployment** | M14 added an API Dockerfile + `docs/DEPLOYMENT.md` + env-driven CORS / uploads. CI/CD is still out of scope. |

---

## 6. Deferred production items

See `docs/NEXT_BACKLOG.md` for the prioritized list of post-Alpha work.

---

## 7. RC verification checklist (run before tagging)

- [ ] `npm install` succeeds at repo root
- [ ] `docker compose up -d postgres` brings up port 5433
- [ ] `npx prisma migrate dev` applies all migrations cleanly on a fresh DB
- [ ] `npm run db:seed` finishes with non-zero counts for all entities
- [ ] `cd apps/api ; npm test` — 158 / 158 green
- [ ] `cd apps/api ; npm run test:e2e` — 43 / 43 green
- [ ] `cd apps/mobile ; flutter analyze` — no errors (info-only output OK)
- [ ] `cd apps/mobile ; flutter test` — 53 / 53 green
- [ ] `cd apps/mobile ; flutter build web --no-tree-shake-icons` — succeeds
- [ ] `bash scripts/smoke.sh` against the running stack — all sections pass
- [ ] All six seeded personas can sign in via the login picker
- [ ] coral sees both 검수 큐 and 운영 대시보드 banners on SpaceList
- [ ] HIDE on a report removes the post from at least 3 read surfaces
- [ ] Image upload + post attach + render works end-to-end on Flutter web
