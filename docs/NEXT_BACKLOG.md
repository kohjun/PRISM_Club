# PRISM Club — Post-Alpha Backlog

What we know we want to add after Alpha RC. Prioritized loosely; each item
sketches the scope so the team can pick it up without re-discovering the
why.

---

## 1. Real authentication (M13 — planned)

**Why:** `X-User-Id` is a development affordance. Production needs verified identity, password / passwordless flows, and tamper-proof sessions.

**Scope sketch:**
- Server-issued JWT (or session row) with role array baked in.
- `POST /v1/auth/login`, `GET /v1/auth/session`, `POST /v1/auth/logout`.
- Flutter: real login form (passwordless dev mode + email/password as fallback). Token stored in `SharedPreferences` (mobile) / cookie / localStorage (web) — at least integrity-protected for alpha.
- Keep `X-User-Id` available only behind a dev-only guard or test helper.
- Migration path: existing seeded users get default credentials.

---

## 2. Deployment + production config (M14 — planned)

**Why:** Right now the API only runs locally with `npm run api:dev`. Alpha needs a deployable artifact.

**Scope sketch:**
- API Dockerfile (multi-stage Node build).
- `npm run start:prod` already exists; verify it boots a built bundle.
- `prisma:migrate:deploy` script + documented usage in CI/CD.
- `docs/DEPLOYMENT.md` — env vars (DATABASE_URL, PRISM_EVENTS_API_BASE_URL, UPLOADS_DIR, CORS_ORIGIN, JWT_SECRET, …).
- Flutter web build with `--dart-define=API_BASE_URL=…` documented per environment.
- Production CORS lock-down (replace `origin: true`).
- Health endpoint should return DB connectivity status, not just `{ ok: true }`.

---

## 3. Real PRISM EVENT / CONTENIDO integration (M15 — planned)

**Why:** EventCard snapshots currently come from `MockEventsClient`. The real ecosystem expects PRISM EVENT to be the source of truth for ticketed events and CONTENIDO for content metadata.

**Scope sketch:**
- Keep `IEventsClient` abstraction.
- Add `PrismEventsClient` with `EVENTS_CLIENT_MODE=prism` selection.
- Normalize remote payloads into existing EventCard fields.
- Handle 404 / timeout / 5xx gracefully (cache local snapshot when remote is down).
- Optional `POST /v1/admin/events/sync` (ADMIN only) for batch refresh.
- `docs/EVENTS_INTEGRATION.md` documenting expected remote shape, mapping, and failure behavior.

---

## 4. Production media storage

**Why:** `apps/api/uploads/` will not survive a container restart or scale to multiple instances.

**Scope sketch:**
- S3-compatible storage abstraction (or Cloudflare R2). Driver chosen by env var.
- Antivirus / content scan hook before serving.
- Image resize pipeline (thumbnails, max-side cap) — sharp or imagemagick.
- Signed URLs for private content if M9 hide ever needs to revoke access.
- `docs/MEDIA_STORAGE.md`.

---

## 5. Push notifications

**Why:** The in-app `notifications` table covers retention, but real users won't reopen the app to discover replies.

**Scope sketch:**
- FCM (Android) + APNS (iOS) + Web Push subscription.
- Notification preferences per type (REPLY_ON_POST opt-out, etc.).
- Worker process (separate from API) consuming a queue of pending pushes.
- Quiet hours, batching, deduplication.

---

## 6. Admin / ops web

**Why:** `OpsDashboardScreen` lives inside the Flutter app today. Moderators may want a tighter desktop-first surface for incidents.

**Scope sketch:**
- Next.js admin app under `apps/admin/`.
- Same role-gated endpoints (CURATOR/MODERATOR/ADMIN).
- Side-by-side moderation review (post + reports + history).
- Bulk operations (bulk-hide spam wave, bulk-resolve same-target reports).
- Audit log viewer (currently only inline in report detail).

---

## 7. Analytics pipeline — partially shipped in M19

**Status:** M19 added a first-party server-side pipeline. See
`docs/ANALYTICS.md` for the taxonomy and admin summary endpoint.

**What's still backlog:**
- Client-side telemetry: today only server-side events are captured. A
  `POST /v1/events/track` ingest for Flutter taps would round it out
  but bring its own privacy / abuse questions.
- External warehouse export (BigQuery / ClickHouse / Snowflake) — for
  long-horizon analysis. Today queries hit the `analytics_events` table
  directly.
- Funnel / cohort dashboards beyond the 30-day rollup card.
- Per-room engagement health.
- A/B framework for trending-score weights.
- Retention job (`DELETE FROM analytics_events WHERE created_at < …`).
  The table grows monotonically right now.

---

## 8. Smaller follow-ups

| Item | Notes |
|---|---|
| Nickname rename + history | Today nicknames are immutable; rename needs to cascade to denormalized references safely. |
| Avatar upload | Profile screen has fallback colored initials; upload UI exists for posts but not for profile photo. |
| Account deletion (GDPR / Korean PIPA) | Right now cascade-deletes work via Prisma onDelete, but no self-serve flow. |
| Email verification + password reset | Required once real auth ships. |
| Soft-delete UI affordance for authors | The DB supports it but Flutter doesn't surface "삭제" reliably from every detail screen. |
| Recruitment post applications | Currently only displays a contact method string; doesn't track applications. |
| Search ranking / Korean morphology | ILIKE works for the demo; production needs a real tokenizer and BM25/vector. |
| Rate limiting | None at the API edge. Throw NestJS throttler in front of write endpoints once auth exists. |
| Observability | Request ID middleware is wired but no log shipping, no metrics, no tracing. |
| ROOM / USER / REFERENCE hide | M9 records audit but doesn't propagate to all surfaces — finish the visibility flip. |
| Rich text / mentions | Post body is plain text. `@nickname` mentions and basic markdown would help. |
| Pagination on profile activity | Activity lists in `GET /v1/users/:id/profile` are capped at 5; add paginated `/users/:id/posts` etc. when needed. |
| Reply depth > 2 | Today blocked at depth 3. Decide whether to extend or formalize. |
