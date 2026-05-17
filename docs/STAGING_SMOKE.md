# PRISM Club — Staging Smoke Workflow

How to run `scripts/smoke.sh` against the staging environment
repeatably, what it touches, how to read failures, and how to clean up
after it.

Pairs with:

- [STAGING_SETUP.md](STAGING_SETUP.md) — how staging is configured
- [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md) — manual QA (per-persona)
  flows; smoke is the curl-driven complement
- [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) §5 — production-side
  smoke procedure

> **Scope.** This doc is for the staging rehearsal. The same script can
> be pointed at production by changing the `API` env var, but production
> normally rejects the `X-User-Id` header that smoke uses — production
> verification uses [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md) instead. See
> §6 below for why.

---

## 1. Prerequisites

Before you run smoke against staging:

- [ ] Staging is set up per [STAGING_SETUP.md](STAGING_SETUP.md) — API
      reachable on a public URL, migrations applied, ops account
      bootstrapped, optional seed data loaded.
- [ ] **The seed has been run** against the staging DB:
      ```bash
      DATABASE_URL="<staging-database-url>" npm run db:seed
      ```
      The script references seeded persona UUIDs
      (`11111111-…` through `66666666-…`) and seeded fixture ids
      (`evt-102`, `dd000000-…`, `99000000-…`, `88800001-…`). Without
      the seed, ~80% of the checks will fail.
- [ ] `ALLOW_X_USER_ID=1` is set on the running API pods (the staging
      default per [STAGING_SETUP.md](STAGING_SETUP.md) §2). The script
      authenticates via `X-User-Id: <persona-uuid>`; the API rejects
      that header when `ALLOW_X_USER_ID` is unset AND `NODE_ENV=production`.
- [ ] `NODE_ENV` is `production` on the staging pods — `ALLOW_X_USER_ID=1`
      keeps the legacy header working without re-enabling the rest of
      the dev guards.
- [ ] You can reach the staging API from wherever you'll run the script.
      Test first:
      ```bash
      curl -sS https://api.staging.<your-domain>/v1/health
      # Expect: {"ok":true}
      ```
- [ ] Local tools available: `bash`, `curl`, `node` (script uses
      `node -e` to parse JSON). All present on a standard Linux / macOS
      dev box; on Windows, run from Git Bash or WSL.

---

## 2. How to mint or obtain test tokens

`scripts/smoke.sh` ships with two auth modes, selected by
`SMOKE_AUTH_MODE`:

| Mode | What the script sends | Target requirement |
|---|---|---|
| `legacy` (default) | `X-User-Id: <persona-uuid>` | `ALLOW_X_USER_ID=1` on the API pod |
| `jwt` | `POST /v1/auth/login` once per persona; subsequent calls send `Authorization: Bearer <token>` | None — works against any reachable API with the seed applied |

In **legacy** mode, the "tokens" are simply the seeded persona UUIDs.
In **jwt** mode, the script mints a real JWT on first use and caches it
for the rest of the run.

| Persona | UUID (constant in `scripts/smoke.sh`) | Roles |
|---|---|---|
| 민서 (minseo) | `11111111-1111-1111-1111-111111111111` | MEMBER |
| joon | `22222222-2222-2222-2222-222222222222` | MEMBER |
| haneul | `33333333-3333-3333-3333-333333333333` | MEMBER |
| coral | `44444444-4444-4444-4444-444444444444` | CURATOR + MODERATOR |
| studio_lead | `55555555-5555-5555-5555-555555555555` | VERIFIED_PLANNER |
| studio_mate | `66666666-6666-6666-6666-666666666666` | VERIFIED_PLANNER |

The M13 section of the smoke script also exercises the real JWT flow
explicitly (login → bearer → /me round-trip), regardless of the chosen
auth mode:

```bash
# Equivalent to what smoke.sh runs internally during the M13 section:
TOKEN=$(curl -sS -X POST "$API/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"11111111-1111-1111-1111-111111111111"}' | jq -r .access_token)

curl -sS -H "Authorization: Bearer $TOKEN" "$API/me"
```

If staging has `ALLOW_X_USER_ID` unset (production-shaped), run smoke
in `jwt` mode — the same assertions still hold:

```bash
SMOKE_AUTH_MODE=jwt API=https://api.staging.<your-domain>/v1 bash scripts/smoke.sh
```

---

## 3. How to run smoke against staging

The script supports an `API` env override (line 10 of `scripts/smoke.sh`,
`API="${API:-http://localhost:3000/v1}"`). Override it inline:

```bash
API=https://api.staging.<your-domain>/v1 bash scripts/smoke.sh
```

The base URL **must end with `/v1`** (the API serves all routes under
the `/v1` prefix; the script appends paths to whatever you supply).

Expected output, one section per milestone, ending with:

```
All smoke checks passed.
```

Wall-clock runtime is ~10–20 seconds depending on staging latency.

### From inside a CI pipeline

```yaml
- name: Smoke staging
  run: bash scripts/smoke.sh
  env:
    API: https://api.staging.${{ secrets.STAGING_DOMAIN }}/v1
```

Exit code is `0` on full pass, non-zero (via `fail`) on first failure.
The script uses `set -euo pipefail`, so any unexpected curl exit also
aborts.

### One-line trigger from your workstation

```bash
# Smoke against staging (legacy header path; needs ALLOW_X_USER_ID=1):
API=https://api.staging.<your-domain>/v1 bash scripts/smoke.sh

# Smoke against staging (JWT path; works without the legacy header):
SMOKE_AUTH_MODE=jwt API=https://api.staging.<your-domain>/v1 bash scripts/smoke.sh

# Smoke against localhost (after npm run api:dev):
bash scripts/smoke.sh
```

The script prints both `Smoke target:` and `Auth mode:` at the top of
the run so a copy of the output records which configuration was
exercised. Operators should attach this header to launch / rehearsal
logs.

---

## 4. How to interpret failures

The script aborts on the first `fail` and prints both the failing
check name and the offending value. Typical failure patterns:

| Symptom | Likely cause | First action |
|---|---|---|
| `/health` fails | API pod is not up or DNS is wrong | `curl https://api.staging.<your-domain>/v1/health` manually; check pod logs |
| `dev/users (got 0)` or `dev endpoints are disabled in production` error | `/v1/dev/users` is dev-only; if `NODE_ENV=production` AND no dev guard relaxation, this returns 403 | Confirm `NODE_ENV=production`, `ALLOW_X_USER_ID=1`. The dev users endpoint specifically requires development-grade access; if your staging hides it, you may need to skip the assertion |
| `hub blocks=0` (or similar low count) | Seed not applied to staging DB | Re-run `DATABASE_URL=<staging-url> npm run db:seed` |
| `search '환승연애' total hits=0` | Same — seed not applied (or applied to a different schema) | Confirm `DATABASE_URL.schema` matches what `migrate deploy` targeted |
| `non-author PATCH -> 403` returns 401 | `ALLOW_X_USER_ID` is unset on staging | Set it to `1` and roll the pod once |
| Random 500 mid-script | Look at the API pod logs; capture the `x-request-id` from the failing response | Check `kubectl logs --tail 100 <api-pod>` (or platform equivalent) |
| `event-card upsert` 502 | `EVENTS_CLIENT_MODE=prism` but upstream is down | Either restore upstream or temporarily set `EVENTS_CLIENT_MODE=mock` and re-roll the pod |
| `member blocked from planner categories ... got 401` | Auth setup is wrong; member can't even authenticate | Same as `non-author PATCH` — re-check `ALLOW_X_USER_ID` |

Any failure where the API returns a non-2xx and the script can't parse
the response, you'll see the raw JSON in the failure message — that
usually has the answer.

### When NOT to roll forward

The script is destructive (see §5). If smoke fails partway through, the
staging DB is in a partial state. Do not "fix and rerun" without
deciding whether to clean up first — running the script again on top of
the partial state can produce confusing duplicate-key errors and
misleading downstream failures.

---

## 5. Which checks are destructive (or create test data)

Per `scripts/smoke.sh`, the persistent effects of one full successful
run on the staging DB are:

### Writes that persist after the run

| Section (heading in the script) | What it leaves behind |
|---|---|
| `reference create` | 1 row in `references`: title="smoke ref", url="https://example.com/r1" |
| `user room creation with pins` | 1 row in `rooms`: name="smoke room", slug auto-derived, plus 2 `room_pins` rows |
| `replies (depth 2 OK, depth 3 rejected)` | 2 `replies` rows attached to the smoke post (post is later soft-deleted, but replies remain) |
| `planner access + recruitment (M4)` | 1 `posts` row in `planner-recruitment` (body="smoke recruitment", status=CLOSED) |
| `event detail (M5)` | Idempotent upsert of `event_cards` for `evt-001`, `evt-002`, `evt-003` (no-op if already seeded) |
| `user profiles + follow (M8)` | `profiles.bio` for minseo set to "smoke test bio"; `profiles.interests = ["smoke"]`; 1 `user_follows` row (haneul → joon) |
| `moderation + reports (M9)` | 1 `reports` row (status=RESOLVED, resolution=HIDDEN) + 1 `moderation_actions` row; seeded post `99000000-…-003` flipped to `status='HIDDEN'` |
| `media attachments (M10)` | 1 `media_assets` row + 1 PNG file at `<UPLOADS_DIR>/<id>.png` (or in the S3 bucket under `<S3_OBJECT_PREFIX>/`) |
| `activity signals (M12)` | `topic_signals` table recomputed (deterministic given current activity — idempotent across runs) |
| `auth sessions (M13)` | None beyond a transient `analytics_events.AUTH_LOGIN` row |
| `analytics events (M19)` | Many `analytics_events` rows accumulated across the run |

### Writes that net to zero

- `events search and event-card upsert` — idempotent upsert; same id second time.
- `post create with attachments` → soft-deleted by `patch/delete enforcement` (`status='DELETED'` rather than physical delete; the post row + its attachments remain in the DB but are filtered from every read surface).
- `reaction toggle` — toggled twice, ends unliked.
- `follow / save / notifications (M6)` — follow toggled twice (net unfollowed); save toggled twice (net unsaved).

### Reads only

`health & dev users`, `topic hub bundle`, `timeline shows new post`,
`search`, `home feed (M7)`, `ops dashboard (M11)`,
`analytics events (M19)`.

---

## 6. Cleanup guidance

Because §5 writes accumulate, repeated smoke runs against the same
staging DB will produce duplicate "smoke room" rows, more reports, and
so on. The post-smoke state is **not** a clean staging environment.

Pick one of:

### Option A — reset between runs (recommended for staging)

```bash
DATABASE_URL="<staging-database-url>" npx prisma migrate reset --force
DATABASE_URL="<staging-database-url>" npm run db:seed
```

`prisma migrate reset --force` drops the schema, reapplies every
migration, and re-runs the seed (per `prisma.seed` in `package.json`).
After it completes, also re-bootstrap any non-seed ops accounts you
created (see [STAGING_SETUP.md](STAGING_SETUP.md) §4.3).

**Never** run `prisma migrate reset` against production. The flag is
documented as a destructive operation precisely because it drops data.

### Option B — targeted cleanup (when you need to keep other state)

If you only want to remove the smoke-specific artifacts (e.g., because
you also have ops-account state you want to preserve):

```sql
\c prism_club_staging

-- "smoke room" + its pins + posts cascade via FK onDelete
DELETE FROM rooms WHERE name = 'smoke room';

-- "smoke ref"
DELETE FROM "references" WHERE title = 'smoke ref';

-- Smoke recruitment post
DELETE FROM posts WHERE body = 'smoke recruitment';

-- Reset minseo's profile (use her seeded values or your preferred ones)
UPDATE profiles
  SET bio = NULL, interests = '[]'::jsonb
  WHERE user_id = '11111111-1111-1111-1111-111111111111';

-- Remove the smoke UserFollow (haneul → joon)
DELETE FROM user_follows
  WHERE follower_id = '33333333-3333-3333-3333-333333333333'
    AND followed_id = '22222222-2222-2222-2222-222222222222';

-- Un-hide the seeded haneul post
UPDATE posts SET status = 'VISIBLE'
  WHERE id = '99000000-0000-0000-0000-000000000003';

-- Resolved smoke report
DELETE FROM reports WHERE reason = 'smoke test';

-- Media asset + file (manual file cleanup needed for local storage;
-- for S3, the row delete leaves the object behind — delete with the
-- bucket console or aws s3 rm).
DELETE FROM media_assets WHERE filename LIKE '%.png' AND size_bytes < 200;

-- Optional: trim analytics events created during smoke
DELETE FROM analytics_events
  WHERE created_at >= NOW() - INTERVAL '1 hour';
```

Option A is simpler and more reliable. Use Option B only when there's
something on staging you really need to keep.

### Why not auto-cleanup in the script?

`scripts/smoke.sh` is intentionally not transactional and intentionally
doesn't reverse its own writes. The same script runs as a verification
gate in CI (where the DB is freshly seeded for each run) and as a
manual smoke during cut-over rehearsal — adding cleanup logic would
make the script branch on environment and risk masking failures. The
operator owns the post-run cleanup decision.

---

## 7. Production note

`scripts/smoke.sh` can be pointed at production. Production normally
has `ALLOW_X_USER_ID` **unset**, so the default `legacy` mode would
fail at the first persona-driven check.

You have three options for production verification:

- **(a)** Run smoke in `jwt` mode — `SMOKE_AUTH_MODE=jwt` logs in each
  persona via `/v1/auth/login` and uses the returned JWT for the rest
  of the run. No auth surface widening needed. **Recommended** when
  the seeded personas exist in the target DB (which is normally not
  the case for production — see the caveat below).
- **(b)** Skip smoke against production entirely and rely on the
  targeted curl checks ([BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md)
  §5) plus the manual persona QA
  ([BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md)) — both already use real
  JWTs.
- **(c)** Set `ALLOW_X_USER_ID=1` for the duration of a legacy-mode
  smoke run, then unset it and roll the pod once.
  [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) §5 documents this as
  the cut-over-only option.

**Caveat about jwt mode in production:** the script's persona UUIDs
(`11111111-…`, etc.) are the seeded demo accounts. They normally do
NOT exist in production. Either seed them deliberately for smoke (not
recommended — they're well-known UUIDs) or take path (b).

Staging usually has the seed applied, so `jwt` mode against staging is
both safe and recommended.

---

## 8. Quick reference card

```bash
# Prereqs: staging API reachable, seed applied.
# Legacy header (requires ALLOW_X_USER_ID=1 on the target):
API=https://api.staging.<your-domain>/v1 bash scripts/smoke.sh

# JWT mode (works without the legacy header — recommended for
# production-shaped staging):
SMOKE_AUTH_MODE=jwt API=https://api.staging.<your-domain>/v1 bash scripts/smoke.sh

# Reset staging DB between runs:
DATABASE_URL="<staging-database-url>" npx prisma migrate reset --force
DATABASE_URL="<staging-database-url>" npm run db:seed

# Bootstrap any non-seed ops accounts after reset:
# (per STAGING_SETUP.md §4.3)
```
