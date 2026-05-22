# PRISM Club — Cutover Rehearsal Guide

A dry-run of the Beta cut-over, executed against the **staging**
environment, with the same actions and the same time budget as the
real production launch. The goal is to surface every "we forgot to
check that" before it costs real users their first impression of
PRISM Club.

> **This is a STAGING-only exercise.** Production cut-over follows
> [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md). The rehearsal
> exists so the operator running that production cut-over has already
> walked the runbook end to end at least once.

Pairs with:

- [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) — production
  execution-time guide (this rehearsal mirrors its §1–§10)
- [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md) — manual QA flows the
  rehearsal exercises
- [STAGING_SETUP.md](STAGING_SETUP.md) — how staging is configured
- [STAGING_SMOKE.md](STAGING_SMOKE.md) — `scripts/smoke.sh` against
  staging
- [DEPLOYMENT.md](DEPLOYMENT.md) — env matrix + Dockerfile
- [HANDOFF.md](HANDOFF.md) — orient first if you're new to the repo

---

## 1. Rehearsal objective

After a successful rehearsal you should be able to answer **yes** to
all five:

1. The image at the target sha can be deployed to staging from a
   clean shell session by following only `BETA_LAUNCH_RUNBOOK.md`,
   without consulting any teammate.
2. The migration step (`prisma migrate deploy`) finishes cleanly
   against the staging DB and the schema matches what the code expects.
3. The smoke + persona QA passes end to end inside the budgeted
   window.
4. Rolling the previous image tag back into place restores service
   in under five minutes, with no data loss.
5. The operator and on-call partner know which monitoring hooks to
   watch during the first hour and can articulate when to roll back
   vs. fix forward.

If any of those is **no** at the end of the rehearsal, file a ticket
before scheduling production.

---

## 2. Required participants

| Role | Responsibility during rehearsal |
|---|---|
| **Operator** | Runs every step from `BETA_LAUNCH_RUNBOOK.md`. Reads commands out loud (or in the shared call) before executing them. |
| **On-call partner** | Shadows the operator. Watches monitoring dashboards. Reads back the §6 hooks from the runbook when asked. Owns the "stop the line" decision. |
| **QA helper (optional)** | Drives the Flutter web client + admin web through [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md). Can be the on-call partner if the team is small. |

Both Operator and On-call partner MUST have read
[HANDOFF.md](HANDOFF.md), [BETA_READINESS.md](BETA_READINESS.md), and
[BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) before the rehearsal
window opens.

Schedule the rehearsal at least **3 business days before** the planned
production cut-over so there is time to fix anything it surfaces.

---

## 3. Timeline

This is the production-shaped budget. Keep it. Padding "just for the
rehearsal" trains the wrong muscle.

```
T-72h ──── pre-flight (§4) on a freshly-cloned repo
T-60m ──── on-call partner ack; status banner up on staging
T-30m ──── migration dry-run + backup snapshot (runbook §3)
T-15m ──── validate envs against runbook §2; pull image
T-0   ──── apply migrations
T+0   ──── roll API pods (one at a time)
T+5m  ──── smoke (§6)
T+10m ──── QA (§7)
T+20m ──── declare "rehearsal success" or hand over to rollback (§8)
T+30m ──── rollback rehearsal (§8 — always, even on success)
T+45m ──── full retro + sign-off (§9 + §10)
```

Total budget: ~120 minutes including retro. If your rehearsal balloons
beyond 180 minutes, that's the actual signal — production cut-over is
going to take longer than you think. Plan accordingly.

---

## 4. Preflight checklist

Run T-72h to T-24h before the rehearsal window opens.

- [ ] Operator has cloned the repo at the target sha on a fresh shell
      session.
- [ ] Operator has run the verification suite locally and confirmed
      every count matches [HANDOFF.md](HANDOFF.md) §4 (158+ unit / 43+
      e2e / 53 Flutter / admin tsc clean / `flutter build web`).
- [ ] Staging matches [STAGING_SETUP.md](STAGING_SETUP.md) §12
      "Pre-cut-over checklist" — all five hosts reachable, TLS valid,
      secrets generated, ops account bootstrapped, smoke green, one
      full QA pass green.
- [ ] On-call partner has access to the staging monitoring dashboards
      and can read the four hooks from
      [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) §6 without
      hunting.
- [ ] Backup snapshot id from the past 60 minutes recorded somewhere
      the operator can reach during rehearsal — the rollback exercise
      depends on it.
- [ ] Previous known-good image tag identified
      (`docker image ls prism-club-api`) — written down before T-0.
- [ ] Status page draft messages ready
      ([BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) §8 comms
      templates).

---

## 5. Deploy dry-run

Walk [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) §4 against
staging. Concretely:

1. **Pull the candidate image.** Either build locally
   (`docker build -t prism-club-api:<sha> -f apps/api/Dockerfile .`)
   or pull from the registry.
2. **Validate envs.** `docker exec <staging-api-pod> env | grep -E
   '^(NODE_ENV|EVENTS_CLIENT_MODE|MEDIA_STORAGE_MODE|NOTIFICATION_DELIVERY_MODE|CORS_ORIGINS|ALLOW_X_USER_ID)='`
   matches the staging values from
   [STAGING_SETUP.md](STAGING_SETUP.md) §2. **Read the output out
   loud.** Don't skim.
3. **Roll one pod first.** Do not roll all replicas simultaneously
   even at staging — that defeats the readiness-probe-gated rollout
   you need to rehearse for production.
4. **Wait for readiness.** `/v1/health/ready` returns 200 before the
   pod takes traffic.
5. **Verify build metadata.** `curl -sS https://<staging-api>/v1/health/version`
   returns the expected `app_version` / `git_sha` / `release_channel`.
   Record the response in the rehearsal log — this is your version of
   "yes, the right image is running."
6. **Verify the diagnostics.** `events-client/status`,
   `analytics/summary`, `ops/summary`, `system-health`, admin web
   reload — same checks you'll run during production. The new
   `GET /v1/admin/system-health` snapshot should return a non-empty
   `metrics` array within ~60s of the first traffic; if it stays
   empty, MetricsService is not being reached and the dashboard is
   blind. Stop and investigate before continuing.
7. **Roll the remaining pods.** Confirm each one passes readiness
   before the next.

If any step fails, **stop and capture context** before retrying. The
rehearsal is more valuable for the failures it surfaces than for the
PASS lines.

---

## 6. Migration dry-run

The migration step is exactly what the production runbook runs. Do not
shortcut it; do not "just run it against a fresh DB" — the
already-migrated staging DB is the realistic test.

```bash
# From the deploy host (or a workstation with reach to staging DB):
DATABASE_URL="<staging-database-url>" npx prisma migrate status
# Expect: "Database schema is up to date!" (already-migrated staging)
# OR a list of pending migrations from this candidate image.

DATABASE_URL="<staging-database-url>" npx prisma migrate deploy
# Expect: exit 0 with each applied migration listed (or "No pending
# migrations to apply." on a no-op rerun).

DATABASE_URL="<staging-database-url>" npx prisma migrate status
# Expect: "Database schema is up to date!" again.
```

If any migration applies (i.e. this candidate adds new schema), open
the migration file and read it during the rehearsal. Flag anything
that:

- drops a column or table
- narrows a column type without a backfill
- alters an index in a way that would lock writes on a large table

Production has more data than staging; staging may apply such a
migration in milliseconds while production stalls. If you see one of
those patterns, plan the production migration window separately —
don't just trust the staging timing.

---

## 6.5. F-series follow-up artifacts

The original Beta plan covers core flows. The F1–F10 follow-ups added
artifacts the rehearsal should exercise once each cut-over, in the
order below. Each is independent — skip the ones that don't apply yet
(e.g. R2 if you're still on local storage).

### 6.5.1 — R2 + CDN media backfill (only when MEDIA_STORAGE_MODE=s3)

Skip when staging still runs `MEDIA_STORAGE_MODE=local`. Once
`S3_BUCKET` / `S3_ENDPOINT` / `MEDIA_PUBLIC_BASE_URL` are wired:

```bash
# dry-run first, always
DATABASE_URL="<staging-database-url>" \
  S3_BUCKET=<staging-bucket> \
  S3_ENDPOINT=<r2-endpoint> \
  MEDIA_PUBLIC_BASE_URL=<cdn-host> \
  npx tsx scripts/migrate-uploads-to-r2.ts --dry-run

# then real run with the same env
DATABASE_URL=... npx tsx scripts/migrate-uploads-to-r2.ts
```

Expected:

- `--dry-run` prints the count of MediaAsset rows whose `cdn_url` is
  null and would be uploaded. Zero is fine on a re-run.
- Real run is idempotent — repeating it must not duplicate uploads or
  rewrite already-CDN-fronted rows.
- After completion, the admin SystemHealthCard shows
  `media.upload.success` increasing as new uploads come in.
- Keep `apps/api/uploads/` for 14 days as belt-and-braces; only
  remove after a clean staging soak.

If the dry-run reports unexpectedly many rows, stop. Either the
backfill ran already (idempotency bug) or someone uploaded to local
storage after the cut-over (env regression). Investigate before
re-running.

### 6.5.2 — Crashlytics symbol upload (Android release builds only)

Crashlytics needs symbol files to symbolicate obfuscated stack traces.
The release pipeline must run **after** the AAB is built:

```bash
cd apps/mobile/android
./gradlew :app:uploadCrashlyticsSymbolFileRelease
```

Verify in the Firebase console:

- The build's `app_version` shows up under Crashlytics → Settings →
  Crashlytics → dSYMs (Android tab).
- Trigger the hidden ops "Throw test exception" button from a release
  build on a real device. Within ~5 minutes the crash appears in the
  Crashlytics console **with line numbers and file paths**. If the
  stack is `<unknown>` lines only, the symbol upload didn't take —
  re-run.

Skip on staging if release-signing config isn't wired yet.

### 6.5.3 — System Health snapshot baseline

After §5 finishes rolling pods, capture the first SystemHealth
snapshot as the "right after deploy" baseline. The first 5 minutes
of traffic populate the curated keys; if a key is still missing after
5 minutes of real traffic, the MetricsService recorder for it isn't
firing.

```bash
curl -sS "$API/admin/system-health" \
  -H "Authorization: Bearer <curator-token>" | jq .
```

Expected first-hour shape (some keys may legitimately stay at 0 if no
traffic of that kind has happened yet — but **all keys should be
present**):

- `search.latency_ms` — any search query bumps `count_1h`.
- `media.upload.success` — any media upload bumps it.
- `notification.push.sent` — empty until a notification fans out.
- `events_client.fetch_ms` — populates as the M5 ingest cron runs.

If a key is missing from the snapshot entirely, the recorder isn't
running. That's the wrong time to discover it — file a ticket
immediately.

---

## 7. Smoke + QA run

### Smoke

```bash
# Two-mode smoke. Run both during rehearsal — production may use either.
API=https://api.staging.<your-domain>/v1 bash scripts/smoke.sh
SMOKE_AUTH_MODE=jwt API=https://api.staging.<your-domain>/v1 bash scripts/smoke.sh
```

Both should print "All smoke checks passed." within ~25 seconds. If
the second (jwt) run fails, you've found a real bug in either the auth
flow or the script's token caching — file a ticket.

Sections covered by `scripts/smoke.sh` (count grows over time —
verify the bottom-of-script section list matches what you expect):

- core M1–M19 flows (topic hub, room, posts, replies, reactions,
  search, planner, event detail, media, ops, signals, auth,
  analytics)
- **F-series additions**: share preview + `/v1/profiles/:id/share-card`
  + `/v1/og/profile/:id.png` (P1.5 / P4.1), saved collections move
  + filter (P4.4), system health snapshot (P5.6).

### Persona QA

Drive [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md) §1–§7 in order. The QA
helper drives the apps; the operator watches; the on-call partner
keeps an eye on the monitoring dashboards (especially
`events-client/status` and `analytics/summary`).

The QA window is the longest single block of the rehearsal. Treat
items §1.10–§1.11 and §3.5 as **non-skippable** — they verify the
read-surface filtering (HIDDEN status, saves, notifications) that
production users actually notice when it breaks.

---

## 8. Rollback rehearsal

Always run this, even on a fully-green deploy dry-run. The first time
you rehearse a rollback should NOT be during a real production
incident.

Pick one of the three paths from
[BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) §7. Recommended for
the rehearsal:

### Path A — image-only revert (5 minute budget)

```bash
# Re-tag the previous known-good image as :current and roll pods.
docker tag prism-club-api:<previous-sha> prism-club-api:current
# Update the platform manifest to use :current and apply.
```

Expected behavior:

- Old image boots; readiness probe passes within ~30s per pod.
- `/v1/health/version` shows the **previous** `git_sha` again. **Read
  this out loud.** This is your "we actually rolled back" signal.
- No DB change required. `prisma migrate status` still reports "up to
  date" against the schema the older image was built to run against
  (the Beta freeze contains no destructive migrations).

Stop the clock when:

- All pods serve traffic on the previous image, AND
- Smoke (legacy or jwt) passes against the rolled-back endpoint, AND
- The QA helper confirms the Flutter web client still works
  end-to-end on at least one persona.

Capture the wall-clock time and compare to the 5-minute budget. If
you blew through it, you have a separate ticket: the rollback path
itself needs to be faster before production.

### Path B (optional) — restore from snapshot

If your platform makes snapshot restore cheap enough, rehearse that
too. Otherwise the unit test is "we know which knob to turn and we've
verified the previous snapshot id is reachable from the platform we'll
restore through." Confirmed once = sufficient.

After the rollback rehearsal, roll **forward** again to the candidate
image so staging is back on the target sha for any follow-up testing.

---

## 9. Sign-off template

Paste the filled version into the rehearsal log / ticket:

```
PRISM Club — Beta Cutover Rehearsal Sign-off
============================================
Date / window     : <YYYY-MM-DD HH:MM-HH:MM TZ>
Operator          : <name>
On-call partner   : <name>
QA helper         : <name or "n/a">

Candidate sha     : <git-sha-of-image-rehearsed>
Staging API host  : https://api.staging.<domain>
Image rolled at   : <T-0 wall clock>

Headless verification (against candidate sha)
  npm run api:test           : <PASS / FAIL — counts>
  npm run api:test:e2e       : <PASS / FAIL — counts>
  npm run admin:typecheck    : <PASS / FAIL>
  flutter analyze            : <PASS / FAIL>
  flutter test               : <PASS / FAIL — counts>
  flutter build web ...      : <PASS / FAIL>

Deploy dry-run (§5)
  Env validation             : <PASS / FAIL>
  /v1/health/version         : <observed app_version / git_sha>
  /v1/admin/events-client/...: <mode / parsed_ok / failures>
  /v1/admin/analytics/summary: <window_days / counts.length>
  Roll wall-clock            : <minutes>

Migration dry-run (§6)
  prisma migrate status      : <up to date / N pending>
  prisma migrate deploy      : <PASS / FAIL>

Smoke (§7)
  legacy mode                : <PASS / FAIL — runtime>
  jwt mode                   : <PASS / FAIL — runtime>

Persona QA (§7 / BETA_QA_SCRIPT.md)
  §1 Member                  : <PASS / FAIL — notes>
  §2 Verified planner        : <PASS / FAIL — notes>
  §3 Curator + moderator     : <PASS / FAIL — notes>
  §4 Admin web               : <PASS / FAIL — notes>
  §5 Media upload            : <PASS / FAIL — notes>
  §6 PRISM EVENT integration : <PASS / FAIL — notes>
  §7 Analytics verification  : <PASS / FAIL — notes>

Rollback rehearsal (§8)
  Path exercised             : <A image revert / B snapshot restore>
  Rollback wall-clock        : <minutes>
  /v1/health/version after   : <previous git_sha confirmed?>

Overall verdict               : <GO for production / NO-GO>
Required fixes before prod    : <list, or "none">

Signed
  Operator        : <name + date>
  On-call partner : <name + date>
```

`Overall verdict: GO` means: every entry above is PASS, the rollback
budget was met, and the operator + on-call partner are both willing
to re-run the same script against production unsupervised.

`Overall verdict: NO-GO` is the default. Move to GO only when the
fixes list is empty.

---

## 10. Failure log template

For each FAIL above, capture:

```
Failure #<n>
============
When                : <T+wall-clock-during-rehearsal>
Step                : <runbook §, e.g. "§4 step 5 Verify build metadata">
Symptom             : <what was observed>
Expected            : <what should have happened>
Request id (if any) : <x-request-id from the failing response>
Logs                : <one-line summary + path / link to full log dump>
Diagnostic state    : <relevant snapshot from /v1/admin/events-client/status,
                       /v1/admin/analytics/summary, ops/summary, etc.>
Triage              : <what was tried; what worked>
Resolution          : <fix forward / rolled back / deferred to ticket>
Follow-up ticket    : <link or "none">
```

Even if the rehearsal ends GO, attach this log — the failures you
caught and fixed are the most valuable artifact for the next person
running cut-over.

---

## 11. After the rehearsal

- [ ] File any tickets that came out of the failure log.
- [ ] Update [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) if you
      found steps that were ambiguous, missing, or out of order.
- [ ] Update [STAGING_SETUP.md](STAGING_SETUP.md) if you found env or
      service requirements that weren't documented.
- [ ] Update this rehearsal guide with anything you'd want next time.
- [ ] If GO: schedule the production cut-over window with stakeholders.
- [ ] If NO-GO: schedule the next rehearsal after fixes land. Do NOT
      schedule production without a green rehearsal on the resolved
      sha.

The rehearsal is a living artifact. Every cut-over feeds back into
both this guide and the runbook.
