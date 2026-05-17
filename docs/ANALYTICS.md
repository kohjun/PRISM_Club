# PRISM Club — Analytics (M19)

PRISM Club ships a small **first-party** analytics pipeline. Server-side
events are written to the `analytics_events` table; nothing leaves the
deployment unless an operator decides to ship rows to an external system
out of band. There is no third-party SDK, no client-side tracking pixel,
no fingerprinting, and no PII in payloads.

This document is the source of truth for:

1. The event taxonomy (every event type that exists today).
2. What is — and isn't — allowed in event payloads.
3. How to read the data.

---

## 1. Why first-party only

Most public communities reach for Mixpanel / Amplitude / Segment for
metrics. We don't. Two reasons:

- **Privacy.** The community is built around small, intimate spaces.
  Routing user actions through third parties — even hashed — increases
  the blast radius of any future breach.
- **Discipline.** A finite per-event payload is enforced in code, not by
  trust. The `scrubPayload` helper drops forbidden keys and trims long
  strings before write.

We can always add an exporter later (cron job → CSV / Parquet / Snowflake).
We can't take user-identifiable data back out of a third-party warehouse.

---

## 2. Event taxonomy

| `event_type` | Triggered by | Payload (allowed keys) |
|---|---|---|
| `AUTH_LOGIN` | `POST /v1/auth/login` | `roles_count: number` |
| `POST_CREATED` | `POST /v1/rooms/:slug/posts` | `post_id`, `room_slug`, `post_type` (`GENERAL`/`RECRUITMENT`), `attachment_count` |
| `REPLY_CREATED` | `POST /v1/posts/:id/replies` | `reply_id`, `post_id`, `is_nested: boolean` |
| `ROOM_FOLLOWED` | `POST /v1/rooms/:slug/follow` (toggle on) | `room_id`, `room_slug` |
| `ROOM_UNFOLLOWED` | `POST /v1/rooms/:slug/follow` (toggle off) | `room_id`, `room_slug` |
| `ITEM_SAVED` | `POST /v1/saves` (toggle on) | `target_type` (`POST`/`REFERENCE`/`EVENT_CARD`), `target_id` |
| `ITEM_UNSAVED` | `POST /v1/saves` (toggle off) | `target_type`, `target_id` |
| `NOTIFICATION_READ` | `POST /v1/notifications/:id/read` | `notification_id`, `notif_type` |
| `REPORT_CREATED` | `POST /v1/reports` | `report_id`, `target_type`, `target_id` |
| `MEDIA_UPLOADED` | `POST /v1/media/images` | `media_id`, `mime_type`, `size_bytes`, `storage_mode` |
| `EVENT_DETAIL_VIEWED` | `GET /v1/events/:id/bundle` | `event_card_id`, `post_count`, `room_count` |

`actor_id` is the authenticated user id (or `null` for unauthenticated
events — currently none, but reserved). `created_at` is the write
timestamp.

---

## 3. Privacy rules (enforced in code)

`AnalyticsService.scrubPayload()` is the gatekeeper. Even if a caller
accidentally passes the wrong field, it is dropped before write:

- **Forbidden keys** (any case, substring match): `body`, `message`,
  `content`, `email`, `phone`, `password`, `token`, `access_token`.
  All silently removed.
- **String values** truncated to 120 characters with `…` suffix.
- **Nested objects** dropped entirely. Payloads stay flat — keys hold
  primitives (string / number / boolean / null) or short arrays (≤ 10).
- **No user-generated content** in any payload. Use ids and counts.
- **No request metadata** (IP, user agent). The actor id is enough.

If you add a new event, add it to the `EventType` union in
`apps/api/src/modules/analytics/analytics.service.ts` and to the table
above. If the payload could ever carry text the user typed, treat it as
forbidden by default and add a key allowlist there instead.

---

## 4. Read paths

### Admin summary endpoint

```
GET /v1/admin/analytics/summary
Authorization: Bearer <admin-or-curator-or-moderator-jwt>
```

Returns 30-day counts grouped by `event_type`:

```json
{
  "window_days": 30,
  "counts": [
    { "event_type": "AUTH_LOGIN", "count": 42 },
    { "event_type": "POST_CREATED", "count": 17 },
    …
  ]
}
```

Returns 403 if the caller lacks `CURATOR`, `MODERATOR`, or `ADMIN`.

The endpoint is also surfaced in the M18 admin web console as a "Last 30
days" card (see `apps/admin/`).

### Direct DB query

```sql
SELECT event_type, COUNT(*) AS n
FROM analytics_events
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY event_type
ORDER BY n DESC;
```

For ad-hoc digging, query the table directly. Indexes:

- `(event_type, created_at DESC)` — fast type-scoped rollups.
- `(actor_id, created_at DESC)` — per-user audit (e.g., "what did this
  account do in the last hour").

---

## 5. Reliability model

Event capture is **fire-and-forget**:

- Callers invoke `analyticsService.record(...)` — a synchronous, void
  method that schedules `recordSafely()` asynchronously.
- Any DB failure inside `recordSafely()` is caught and logged at WARN
  level; the original business transaction (login, post create, etc.)
  is never affected.
- Lost events are acceptable. We do not retry, do not buffer to disk, do
  not block the request thread.

If you ever need stricter guarantees (e.g., for billing or compliance),
this is the wrong pipeline — use a real outbox + queue.

---

## 6. Operational notes

- The table grows monotonically. There is no built-in retention. For
  the alpha environment that's fine; pruning is on `docs/NEXT_BACKLOG.md`.
- A simple pruner is `DELETE FROM analytics_events WHERE created_at <
  NOW() - INTERVAL '90 days';` — safe to run as a nightly job.
- Do not add foreign keys to `actor_id`. We want event rows to survive a
  user deletion as an audit record.
- The schema is intentionally simple: `id`, `actor_id`, `event_type`,
  `payload (jsonb)`, `created_at`. No `version`, no `source`, no
  `session_id`. Add them only when there's a concrete reader that needs
  them.
