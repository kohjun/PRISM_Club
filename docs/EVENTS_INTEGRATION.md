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

`PrismEventsClient.normalize()` converts the remote DTO into the local
`ExternalEvent` interface:

| Local field | Remote source | Notes |
|---|---|---|
| `external_event_id` | `id` | Stored as the natural key of the EventCard snapshot. |
| `title` | `title` | Required. Items without a title are dropped from search. |
| `venue_name` | `venue.name` | Empty string if missing. |
| `region` | `venue.region` | Empty string if missing. |
| `starts_at` | `starts_at` | Required ISO 8601 string. |
| `event_status` | `status` | `'COMPLETED'` if remote sends `COMPLETED`; otherwise `'UPCOMING'`. |
| `thumbnail_url` | `thumbnail_url` | Nullable. |

The mapper SKIPS items missing required fields (id / title / starts_at)
rather than throwing — search results stay resilient when upstream returns
partial data.

The upsert into `event_cards` happens via the existing
`EventCardService.upsertByExternalEventId()` (M1). The mock and prism
clients hit the same upsert path, so M5 EventDetail behavior is identical
either way.

---

## 5. Failure behavior

| Failure | `search()` | `getById()` |
|---|---|---|
| Network error / DNS / connection refused | returns `[]` | returns `null` |
| Timeout (`PRISM_EVENTS_TIMEOUT_MS`) | returns `[]` | returns `null` |
| Upstream 4xx (not 404) | returns `[]` (logs warning) | returns `null` (logs warning) |
| Upstream 404 | returns `[]` | returns `null` |
| Upstream 5xx | returns `[]` (logs warning) | returns `null` (logs warning) |
| Malformed JSON / missing required fields | returns `[]` (logs warning) | returns `null` |
| `PRISM_EVENTS_API_BASE_URL` not set | returns `[]` (logs warning) | returns `null` |

In every case, Club surfaces continue to render — the user sees an empty
"no related events" state instead of a 500. Local `EventCard` snapshots
persist after the first successful upsert, so existing posts that attach
an EventCard keep working even if the upstream is down for hours.

---

## 6. Local mock mode details

`MockEventsClient` is backed by `mock-events.fixtures.json`. It:

- Adds 80–149 ms artificial latency so loading states are visible.
- Filters by case-insensitive substring on title / venue / region.
- Supports `status=UPCOMING|COMPLETED` filtering.

The fixture is intentionally tiny — seeded events `dd000000-…-001/-002/-003`
plus a few extra rows the mobile picker can list. This is what every
existing unit test, e2e test, and `scripts/smoke.sh` run sees.

---

## 7. Future work

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
