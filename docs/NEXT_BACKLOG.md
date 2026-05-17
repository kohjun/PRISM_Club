# PRISM Club — Post-Beta Backlog

What we know we want to add after Beta. Prioritized loosely; each item
sketches the scope so the team can pick it up without re-discovering the
why.

> **Status note (post-M20):** M13–M18 (auth, deployment, events client,
> media storage, notification delivery boundary, admin web console) and
> M19–M20 (analytics events + PRISM EVENT contract hardening) have all
> shipped. This document tracks what is *still* deferred — items that are
> in scope for the post-Beta release sequence.

---

## 1. Real authentication (M13 boundary → production flow)

**Why:** M13 added JWT sessions, but login is still passwordless — any
seeded user id signs you in. Beta exposes the surface to real users; this
is the gating item before opening signup.

**Scope sketch:**
- Email + password (Argon2 hash) or OAuth (Google / Kakao / Naver).
- Signup endpoint + email verification flow.
- Password reset (token email).
- Optional MFA.
- Drop the `X-User-Id` fallback entirely once tests/smoke move to
  obtaining a JWT via `/v1/auth/login`.
- Persist sessions in a `sessions` table (so logout can actually
  invalidate) or move to short-lived JWT + refresh tokens.

---

## 2. Notification delivery — wire real providers (M17 boundary → live)

**Why:** M17 added `INotificationDeliverer` with `email` and `push`
boundary stubs. The contract is in place; the actual provider integration
is not.

**Scope sketch:**
- **Email:** pick one of Resend / Postmark / SES; implement the
  `EmailDelivery` stub against it. Use the `EMAIL_PROVIDER`,
  `EMAIL_FROM_ADDRESS`, `EMAIL_API_KEY`, `EMAIL_REGION` env shape
  already documented.
- **Push:** FCM (Android) + APNS (iOS) + Web Push. Add a
  `device_tokens` table keyed on user.
- Notification preferences per type (REPLY_ON_POST opt-out, etc.).
- Quiet hours, batching, deduplication.
- Worker process (separate from API) consuming the delivery queue, if
  the synchronous fan-out gets too noisy.

---

## 3. Analytics — exporter + retention + dashboards

**Why:** M19 captures server-side events into `analytics_events`. There
is no exporter, no retention job, and the only read path is a 30-day
rollup. Long-horizon analysis requires landing somewhere else.

**Scope sketch:**
- Nightly exporter to BigQuery / ClickHouse / Snowflake (CSV or
  Parquet via S3).
- Retention job: `DELETE FROM analytics_events WHERE created_at <
  NOW() - INTERVAL '90 days';` — the table grows monotonically today.
- Funnel / cohort dashboards (e.g. signup → first post → first
  follow → second visit).
- Per-room engagement health.
- A/B framework for trending-score weights.
- Optional client-side telemetry (`POST /v1/events/track`) for taps —
  needs an abuse/rate-limit design before opening.

---

## 4. Media storage — production polish (M16 boundary → safety net)

**Why:** M16 added S3-compatible storage. Beta still needs the safety
features the alpha env doesn't have.

**Scope sketch:**
- Antivirus / content scan hook before serving.
- Image resize pipeline (thumbnails, max-side cap) — `sharp` or
  ImageMagick.
- Signed URLs for hide-protected content once ROOM/USER hide ships.
- CDN in front (CloudFront / Cloudflare).
- One-time migration script for any `apps/api/uploads/` files left
  on disk in legacy environments.
- `docs/MEDIA_STORAGE.md` walking through the S3 setup end to end.

---

## 5. Admin web — bulk ops + audit log (M18 polish)

**Why:** M18 admin console renders ops summary + open report queue +
signal refresh + events client status + analytics rollup. Moderators
still need higher-throughput affordances for incident response.

**Scope sketch:**
- Side-by-side moderation review (post body + reports + history) on
  one screen.
- Bulk operations (bulk-hide spam wave, bulk-resolve same-target
  reports).
- Audit log viewer (today the only audit surface is inline in report
  detail).
- Role-grant UI (Admin → Verified Planner promotion is seed-only).
- A view onto `analytics_events` beyond the 30-day rollup card —
  searchable / filterable per-actor history.

---

## 6. Smaller follow-ups

| Item | Notes |
|---|---|
| Nickname rename + history | Today nicknames are immutable; rename needs to cascade to denormalized references safely. |
| Avatar upload | Profile screen has fallback colored initials; upload UI exists for posts but not for profile photo. |
| Account deletion (GDPR / Korean PIPA) | Cascade-deletes work via Prisma `onDelete`, but no self-serve flow. |
| Soft-delete UI affordance for authors | The DB supports it but Flutter doesn't surface "삭제" reliably from every detail screen. |
| Recruitment post applications | Currently only displays a contact method string; doesn't track applications. |
| Search ranking / Korean morphology | ILIKE works for the demo; production needs a real tokenizer and BM25 / vector. |
| Rate limiting | None at the API edge. Throw NestJS throttler in front of write endpoints once auth is real. |
| Observability | Request-id middleware is wired but no log shipping, no metrics, no tracing. |
| ROOM / USER / REFERENCE hide | M9 records audit but doesn't propagate to all surfaces — finish the visibility flip. |
| Rich text / mentions | Post body is plain text. `@nickname` mentions and basic markdown would help. |
| Pagination on profile activity | Activity lists in `GET /v1/users/:id/profile` are capped at 5; add paginated `/users/:id/posts` etc. when needed. |
| Reply depth > 2 | Today blocked at depth 3. Decide whether to extend or formalize. |
| Real-time updates | No WebSocket / SSE; clients poll on screen entry. |
| Native mobile distribution | Web bundle works today; App Store / Play submissions not started. |
| Sessions table for /auth/logout | Logout is a no-op stub on stateless JWT — needs a revocation list or short-lived tokens. |
