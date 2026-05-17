# PRISM Club — PRISM EVENT / CONTENIDO Integration

PRISM Club consumes external event data through a single abstraction —
`IEventsClient` — and stores a local **snapshot** in the `event_cards`
table. All Club surfaces (Topic Hub related events, Event Detail, search,
home feed) read the local snapshot. The external source of truth is
refreshed via this client.

This doc describes the two client modes, the expected upstream contract,
how Club maps remote data into `EventCard`, and how failures degrade.

---

## 1. Client modes

Selected at boot via `EVENTS_CLIENT_MODE`.

| Mode | When to use | Activator |
|---|---|---|
| `mock` (default) | Local dev, demos, CI, e2e tests | `EVENTS_CLIENT_MODE=mock` (or unset) |
| `prism` | Alpha / production | `EVENTS_CLIENT_MODE=prism` AND `PRISM_EVENTS_API_BASE_URL` set |

If `EVENTS_CLIENT_MODE=prism` is set but `PRISM_EVENTS_API_BASE_URL` is
not, `EventLinkModule` logs a warning and binds the mock client. This is
intentional — it keeps containers from crashing on misconfigured envs and
makes failures show up at the boundary instead of inside callers.

---

## 2. Environment variables

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `EVENTS_CLIENT_MODE` | no | `mock` | `mock` or `prism`. |
| `PRISM_EVENTS_API_BASE_URL` | yes for prism | _(empty)_ | Base URL of the upstream API, no trailing slash. |
| `PRISM_EVENTS_API_KEY` | no | _(empty)_ | When set, sent as `Authorization: Bearer …` on every request. |
| `PRISM_EVENTS_TIMEOUT_MS` | no | `4000` | Per-request timeout. Triggers `AbortController.abort()` on overrun. |

These live in `.env.example` and are documented in `docs/DEPLOYMENT.md`.

---

## 3. Expected upstream API shape

The real PRISM EVENT / CONTENIDO API is not finalized at Alpha. The
client adapts to whatever endpoint shape we land on; today it expects:

### `GET {BASE}/events?q=<query>&status=UPCOMING|COMPLETED`

```json
{
  "items": [
    {
      "id": "evt-100",
      "title": "소개팅 미션 나이트",
      "venue": { "name": "홍대 스튜디오", "region": "서울/홍대" },
      "starts_at": "2026-09-01T19:00:00Z",
      "status": "UPCOMING",
      "thumbnail_url": "https://cdn.prism.app/events/100.png"
    }
  ]
}
```

### `GET {BASE}/events/:externalEventId`

Same shape as one item from the search response. Returns 404 when not found.

---

## 4. Mapping into `EventCard`

`PrismEventsClient.parseAndNormalize()` validates the remote DTO with a
**zod schema** (`PrismEventDTOSchema`) and converts it into the local
`ExternalEvent` interface:

| Local field | Remote source | Required? | Notes |
|---|---|---|---|
| `external_event_id` | `id` | yes — must be non-empty string | Stored as the natural key of the EventCard snapshot. |
| `title` | `title` | yes — must be non-empty string | Items with empty/missing title are dropped. |
| `venue_name` | `venue.name` | no | Empty string if missing. |
| `region` | `venue.region` | no | Empty string if missing. |
| `starts_at` | `starts_at` | yes — must be ISO 8601 parseable by `Date.parse()` | Items with unparseable timestamps are dropped. |
| `event_status` | `status` | no — defaults to `'UPCOMING'` | Must be exactly `'UPCOMING'` or `'COMPLETED'` if present. Unknown values reject the whole row. |
| `thumbnail_url` | `thumbnail_url` | no — preserved as null if absent | Nullable. |

The mapper SKIPS rows that fail validation rather than throwing — search
results stay resilient when upstream returns partial or malformed data.
Each skip increments `stats.parse_failed` (see §6 below) so contract
drift is visible without grepping logs.

The upsert into `event_cards` happens via the existing
`EventCardService.upsertByExternalEventId()` (M1). The mock and prism
clients hit the same upsert path, so M5 EventDetail behavior is identical
either way.

### Zod schema (source of truth)

```typescript
export const PrismEventDTOSchema = z.object({
  id: z.string().min(1),
  title: z.string().min(1),
  starts_at: z.string().min(1),
  venue: z.object({
    name: z.string().optional(),
    region: z.string().optional(),
  }).partial().optional(),
  status: z.enum(['UPCOMING', 'COMPLETED']).optional(),
  thumbnail_url: z.string().nullable().optional(),
});
```

Defined alongside the client in
`apps/api/src/modules/event-link/clients/prism-events.client.ts`.

---

## 5. Failure behavior

| Failure | `search()` | `getById()` | Counter incremented |
|---|---|---|---|
| Network error / DNS / connection refused | returns `[]` | returns `null` | `http_errors` |
| Timeout (`PRISM_EVENTS_TIMEOUT_MS` triggers `AbortError`) | returns `[]` | returns `null` | `timeouts` |
| Upstream 4xx (not 404) | returns `[]` (logs warning) | returns `null` (logs warning) | `http_errors` |
| Upstream 404 | returns `[]` | returns `null` | none |
| Upstream 5xx | returns `[]` (logs warning) | returns `null` (logs warning) | `http_errors` |
| Malformed envelope (no `items` array) | returns `[]` (logs warning) | n/a | `parse_failed` |
| Row missing required field (id / title / starts_at) | row skipped, others returned | returns `null` | `parse_failed` |
| Row with unparseable `starts_at` | row skipped | returns `null` | `parse_failed` |
| Row with unknown `status` value | row skipped | returns `null` | `parse_failed` |
| `PRISM_EVENTS_API_BASE_URL` not set | returns `[]` (logs warning) | returns `null` | none |

In every case, Club surfaces continue to render — the user sees an empty
"no related events" state instead of a 500. Local `EventCard` snapshots
persist after the first successful upsert, so existing posts that attach
an EventCard keep working even if the upstream is down for hours.

---

## 6. Observability and admin diagnostic

The `PrismEventsClient` keeps a cumulative in-memory counter of parse and
HTTP outcomes. The admin web console reads it via:

```
GET /v1/admin/events-client/status
Authorization: Bearer <curator-or-moderator-or-admin-jwt>
```

Response:

```json
{
  "mode": "prism",
  "base_url_configured": true,
  "timeout_ms": 4000,
  "stats": {
    "parsed_ok": 184,
    "parse_failed": 0,
    "http_errors": 0,
    "timeouts": 0,
    "last_error": null,
    "last_error_at": null
  }
}
```

When `EVENTS_CLIENT_MODE=mock` (or fallback from misconfigured prism
mode), the response has `mode: "mock"` and a `note` explaining why. The
counters are zeroed on process restart — there's no persistence yet, so
for long-term tracking, scrape the endpoint into your monitoring system.

The M18 admin app surfaces this as a dashboard card titled "Events
client" so operators can spot contract drift (`parse_failed > 0`) or
upstream incidents (`timeouts / http_errors > 0`) without grepping logs.

Role gate: `CURATOR` / `MODERATOR` / `ADMIN`.

---

## 7. Local mock mode details

`MockEventsClient` is backed by `mock-events.fixtures.json`. It:

- Adds 80–149 ms artificial latency so loading states are visible.
- Filters by case-insensitive substring on title / venue / region.
- Supports `status=UPCOMING|COMPLETED` filtering.

The fixture is intentionally tiny — seeded events `dd000000-…-001/-002/-003`
plus a few extra rows the mobile picker can list. This is what every
existing unit test, e2e test, and `scripts/smoke.sh` run sees.

---

## 8. Future work

Tracked in `NEXT_BACKLOG.md`:

- Admin "sync" endpoint (`POST /v1/admin/events/sync`) to bulk-refresh
  EventCards from the remote source.
- Webhook ingestion for push-style updates instead of pull-only.
- Local TTL on `event_cards.syncedAt` so the EventDetail bundle can fall
  back to remote when the snapshot is stale.
- Multi-tenant key support (per-region, per-brand events).

None of these are required for the Alpha RC. Mock mode is fully
self-contained; prism mode is API-ready but waits on the real CONTENIDO
endpoint contract to lock down.
