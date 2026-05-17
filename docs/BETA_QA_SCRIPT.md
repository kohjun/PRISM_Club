# PRISM Club — Beta QA Script

Manual test script for the Beta cut-over. Pairs with
[BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) §9 — that section is
the **gate** (one line per step, pass/fail), this document is the
**recipe** (what to tap, what to expect, what to do if it doesn't).

> **Audience:** the engineer running QA after `migrate deploy` + pod
> rollout, the on-call partner shadowing, and the QA helper account-
> holder driving the apps.

This script runs against the deployed environment after the migration +
pod rollout. Each section is **independent** — you can rerun any one
without resetting the others — but the **order matters** for analytics
verification at the end (the analytics flow checks that the prior
sections actually generated events).

---

## 0. Setup

### 0.1 Hosts you need

| Surface | URL |
|---|---|
| API | `https://<api-host>/v1` |
| Admin web | `https://<admin-host>` |
| Flutter web client | `https://<club-host>` |

Record the actual values in your cut-over log; the rest of this script
abbreviates as `<api-host>`, `<admin-host>`, `<club-host>`.

### 0.2 Test accounts

Beta does NOT ship signup. Create these accounts via SQL **before** the
QA window opens. Record each user_id in the cut-over log.

```sql
-- Member (qa_member)
INSERT INTO users (id, status) VALUES (gen_random_uuid(), 'ACTIVE') RETURNING id;
-- Capture <member-uuid> from the previous statement.
INSERT INTO profiles (user_id, nickname) VALUES ('<member-uuid>', 'qa_member');

-- Verified Planner (qa_planner)
INSERT INTO users (id, status) VALUES (gen_random_uuid(), 'ACTIVE') RETURNING id;
INSERT INTO profiles (user_id, nickname) VALUES ('<planner-uuid>', 'qa_planner');
INSERT INTO user_roles (id, user_id, role, source)
  VALUES (gen_random_uuid(), '<planner-uuid>', 'VERIFIED_PLANNER', 'qa-setup');

-- Curator + Moderator (qa_curator)
INSERT INTO users (id, status) VALUES (gen_random_uuid(), 'ACTIVE') RETURNING id;
INSERT INTO profiles (user_id, nickname) VALUES ('<curator-uuid>', 'qa_curator');
INSERT INTO user_roles (id, user_id, role, source)
  VALUES (gen_random_uuid(), '<curator-uuid>', 'CURATOR', 'qa-setup');
INSERT INTO user_roles (id, user_id, role, source)
  VALUES (gen_random_uuid(), '<curator-uuid>', 'MODERATOR', 'qa-setup');
```

(`bootstrap-admin` already exists from launch §1; the QA helper accounts
are kept separate so you can revoke them after the window closes
without losing your admin login.)

### 0.3 Tokens you need

The Flutter and admin web apps obtain JWTs through the in-app login.
For curl-based checks (§6, §7), mint tokens manually:

```bash
MEMBER_TOKEN=$(curl -sS -X POST -H "Content-Type: application/json" \
  -d '{"user_id":"<member-uuid>"}' \
  https://<api-host>/v1/auth/login | jq -r .access_token)

PLANNER_TOKEN=$(curl -sS -X POST -H "Content-Type: application/json" \
  -d '{"user_id":"<planner-uuid>"}' \
  https://<api-host>/v1/auth/login | jq -r .access_token)

CURATOR_TOKEN=$(curl -sS -X POST -H "Content-Type: application/json" \
  -d '{"user_id":"<curator-uuid>"}' \
  https://<api-host>/v1/auth/login | jq -r .access_token)

ADMIN_TOKEN=$(curl -sS -X POST -H "Content-Type: application/json" \
  -d '{"user_id":"<bootstrap-admin-uuid>"}' \
  https://<api-host>/v1/auth/login | jq -r .access_token)
```

If a login returns 401, the user_id is wrong or `users.status` isn't
`ACTIVE`. If it returns 500, the API is broken — abort QA and triage.

### 0.4 If a step fails

Capture and continue with the rest of the script unless the failure
indicates SEV-1 (see runbook §8):

1. The exact request you ran (URL, method, body).
2. The full response body (including any `x-request-id` header).
3. A screenshot if the failure was in the Flutter or admin web client.
4. The deploy sha of the running API pod.

File a ticket; don't try to fix forward during QA.

---

## 1. Member QA flow

Persona: **qa_member**, MEMBER role only.

### 1.1 Login

1. Open `https://<club-host>` in a fresh browser tab (clear localStorage
   first or use Incognito).
2. The login picker shows. Paste the qa_member user_id, submit.
3. **Expect:** redirect to `/home`. The route is the `HomeShellScreen`
   with a 5-tab `NavigationBar` (홈 / 검색 / 커뮤니티 / 저장 / 알림).
4. **Verify in DevTools:** localStorage contains an access token. The
   network tab shows subsequent requests carry
   `Authorization: Bearer <token>`.

### 1.2 Home bundle

1. Wait for `/home` to finish loading.
2. **Expect:** the page renders multiple sections:
   - unread notification badge (may be 0)
   - followed-room updates (empty for a fresh account)
   - recommended rooms
   - recommended events
   - trending posts
   - active topic hubs
   - recent saves (empty for a fresh account)
3. **If empty:** scroll to confirm at least "recommended rooms" /
   "recommended events" / "trending posts" / "active topic hubs" have
   content seeded by the QA test data.
4. **Failure mode:** all sections empty → either the seeded data hasn't
   reached prod, or the home bundle endpoint is broken. Hit
   `GET /v1/home` directly to triage.

### 1.3 Search

1. Tap **검색** in the bottom nav.
2. **Expect:** empty-state shows a chip row of popular topics.
3. Type `소개팅` (or another known-seeded keyword) in the search box.
4. **Expect:** results appear grouped by entity type (Topic Hub /
   knowledge / room / post / event card / reference). At least one
   group has hits.
5. Tap a chip-row filter to narrow to one entity type. The list
   updates.

### 1.4 Topic Hub + Event Detail

1. Tap **커뮤니티** in the bottom nav. The space list renders.
2. Tap a public space (the 참가자 space). Category list opens.
3. Tap any category. The Topic Hub renders with:
   - knowledge blocks
   - signals chip row
   - related rooms list
   - related events list
4. Tap a related event tile.
5. **Expect:** `/events/<cardId>` renders with hero card + 관련 방
   section + 관련 글 section + a "글 작성" CTA at the bottom.
6. **Failure mode:** event detail shows an error toast → check
   `/v1/admin/events-client/status` for `parse_failed` or `http_errors`.

### 1.5 Room timeline + follow

1. Back to the Topic Hub. Tap a related room.
2. **Expect:** room timeline opens; existing posts visible.
3. Tap **팔로우** in the AppBar.
4. **Expect:** the button text flips to **팔로잉**; follower count
   increments by 1.
5. Refresh the page (or pop and re-enter the screen) and confirm the
   follow state persists.

### 1.6 Post compose (text)

1. From the room timeline, tap the FAB or composer entry.
2. Type a body: `qa_member post check — <timestamp>`.
3. Submit.
4. **Expect:** the new post appears at the top of the timeline within
   ~1 second; redirected back to the timeline.

### 1.7 Post compose (with image)

1. Tap composer again. Type a body.
2. Tap the image picker, choose a sample jpg/png/webp/gif under 5 MB.
3. **Expect:** an inline preview thumbnail renders with an X to remove.
4. Submit.
5. **Expect:** the new post appears with the image thumbnail. Tapping
   the image opens it at full size.
6. **Verify URL:** the image src points at `<MEDIA_PUBLIC_BASE_URL>/...`
   when `MEDIA_STORAGE_MODE=s3`, or `/uploads/<id>.<ext>` in local mode.

### 1.8 Author tap → profile → user-follow

1. From any post in the timeline, tap the author avatar / nickname.
2. **Expect:** `/users/<author-id>` profile renders with role badges
   (where applicable), counts, recent posts, owned rooms, approved
   contributions.
3. Tap **팔로우**.
4. **Expect:** the button flips to **팔로잉**; follower count
   increments.

### 1.9 Report a post

1. From a post detail (tap into a post), open the `⋯` menu.
2. Tap **신고**.
3. **Expect:** the report sheet opens with reason options + optional
   detail textarea.
4. Pick a reason (e.g. "spam"), submit.
5. **Expect:** 201 OK; the sheet closes; a success toast appears.
6. **Verify:** subsequent submit attempts for the same target return
   409 Conflict (one open report per reporter per target).

### 1.10 Notifications

1. From a fresh tab, log in as the qa_curator account.
2. Reply to qa_member's post created in 1.6.
3. Switch back to the qa_member tab.
4. Tap **알림** in the bottom nav.
5. **Expect:** unread badge ≥ 1; the new `REPLY_ON_POST` notification
   shows.
6. Tap the notification.
7. **Expect:** marked-as-read indicator flips; badge count decreases by
   1; the route navigates to the parent post.

### 1.11 Saves

1. From the same post, tap the bookmark icon.
2. Tap **저장** in the bottom nav.
3. **Expect:** the post appears under the POST filter chip.
4. Toggle the bookmark off; refresh **저장**; the entry is gone.

---

## 2. Verified Planner QA flow

Persona: **qa_planner**, VERIFIED_PLANNER role.

### 2.1 Login + planner space unlock

1. New Incognito tab → log in as qa_planner.
2. Tap **커뮤니티** in the bottom nav.
3. **Expect:** the 기획자 스튜디오 card shows as unlocked (no lock
   dialog when tapped).
4. **Verify negative case (optional):** in another tab as qa_member,
   tap the same card → lock dialog explains the access policy.

### 2.2 Recruitment room

1. From 기획자 스튜디오 → category → topic hub → 스태프 모집 공고 room.
2. **Expect:** existing recruitment posts render with structured fields
   (역할 / 일정 / 장소 / 보상 / 인원 / 지원 방법) and a status chip
   (OPEN / CLOSED / FILLED).

### 2.3 Compose recruitment post

1. Tap the FAB ("모집 글쓰기").
2. **Expect:** RecruitmentComposer opens with the seven structured
   fields.
3. Fill them in:
   - role: "QA 헬퍼"
   - schedule: "<future date> 19:00"
   - location: "원격"
   - compensation: "50,000 KRW"
   - capacity: "2"
   - application_method: "이메일로 연락"
4. Submit.
5. **Expect:** new post appears at the top of the timeline with status
   chip OPEN.

### 2.4 Status toggle

1. From the post you just created, find the author-only status action.
2. Toggle OPEN → CLOSED.
3. **Expect:** chip updates; followers of the room receive a
   `RECRUITMENT_STATUS_CHANGED` notification on their next refresh.
4. Toggle CLOSED → FILLED. The chip updates again.

### 2.5 Member can't see planner content

1. Switch to the qa_member tab.
2. Open the global search and look for "QA 헬퍼" or the keyword you
   used in 2.3.
3. **Expect:** zero hits in the post group. PLANNER_ONLY content is
   filtered out for members.

---

## 3. Curator + Moderator QA flow

Persona: **qa_curator**, CURATOR + MODERATOR roles.

### 3.1 Banners on SpaceList

1. New Incognito tab → log in as qa_curator.
2. Tap **커뮤니티** in the bottom nav.
3. **Expect:** SpaceList shows two top banners:
   - 검수 큐로 가기 (CURATOR)
   - 운영 대시보드 (CURATOR / MODERATOR / ADMIN)

### 3.2 Ops dashboard

1. Tap **운영 대시보드** → `/admin/ops`.
2. **Expect:** counter cards render:
   - Pending contributions
   - Open reports (≥ 1 if §1.9 ran)
   - Recruitment open / total
   - Recent users (30d)
   - Recent rooms (30d)
   - Recent posts (30d)
3. Each card is tappable and deep-links to the corresponding queue.

### 3.3 Refresh signals

1. From the ops dashboard AppBar, tap **시그널 새로고침**.
2. **Expect:** snackbar appears: `Refreshed N hubs · M signals written`.
3. **Verify in DB (optional):**
   ```sql
   SELECT COUNT(*) FROM topic_signals;
   ```
   Count should be > 0 after the refresh.

### 3.4 Moderation queue

1. Tap **Open reports** card → `/admin/reports`.
2. **Expect:** the report submitted by qa_member in §1.9 appears in the
   list.
3. Tap the report → detail screen.
4. **Expect:** target summary (with a preview of the offending post),
   reporter info, audit history (empty for OPEN reports), HIDE /
   RESTORE / DISMISS buttons.

### 3.5 Resolve with HIDE

1. With the report detail open, tap **HIDE** with an optional moderator
   note: `qa hide`.
2. **Expect:** success toast; report status flips to RESOLVED with
   resolution HIDDEN.
3. **Verify negative cases (in the qa_member tab):**
   - The hidden post disappears from the room timeline.
   - Global search returns zero hits for the post body.
   - The `/home` bundle (if it was trending) no longer includes the
     post.
   - The author's profile activity (`/users/<author>/profile`) no longer
     lists the post in recent posts.
   - Saves: if qa_member had bookmarked it, the entry no longer renders
     in `/me/saves`.

### 3.6 Curation queue

1. Back to `/admin/ops`, tap the pending contributions card →
   `/curate`.
2. **Expect:** list of PENDING knowledge contributions (use the seeded
   ones or have qa_member submit a new contribution).
3. Tap a contribution → detail screen with proposed change, evidence,
   and APPROVE / 거절 / 보완 요청 buttons.
4. Tap APPROVE.
5. **Expect:**
   - Success toast.
   - The contribution's status flips to APPROVED.
   - The target knowledge block reflects the new content.
   - The contribution row carries `snapshot_block_type / title / body`
     of the pre-approval content (audit trail).
6. **Verify in qa_member tab:** open the Topic Hub the block lives on
   — the new content is visible.

---

## 4. Admin web QA flow

Persona: **bootstrap-admin** (ADMIN) — created in
[BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) §1.

### 4.1 Login

1. Open `https://<admin-host>` in a fresh browser tab.
2. **Expect:** the login form shows two inputs (API base URL, User ID)
   plus a submit button.
3. Confirm API base URL is the production value (the admin web bundle
   was built with `VITE_API_BASE_URL=...`; the input pre-fills that).
4. Paste the bootstrap admin user_id, submit.
5. **Expect:** dashboard renders. Top bar shows the nickname + role
   chips (`ADMIN` or `CURATOR · MODERATOR · ADMIN`) + 새로고침 +
   로그아웃 buttons.

### 4.2 Negative case — non-ops account

1. Log out.
2. Try to log in with qa_member's user_id.
3. **Expect:** an access denied banner explains that the account needs
   CURATOR / MODERATOR / ADMIN. The dashboard does NOT render.

### 4.3 Dashboard cards

Log back in as bootstrap-admin. **Expect** every card below to render:

| Card | What to verify |
|---|---|
| **Pending contributions** | Count matches `/v1/admin/ops/summary.pending_contributions.count`. |
| **Open reports** | Count matches `open_reports.count` AND the "Open report queue" full-width table below lists at least the reports submitted in QA. |
| **Recruitment posts** | `count_open / count_total` matches the API. |
| **Signals** | "시그널 새로고침" button is clickable; clicking returns a `Refreshed N hubs · M signals written` line. |
| **Events client** | `mode` matches `EVENTS_CLIENT_MODE` env. `base_url_configured` matches whether `PRISM_EVENTS_API_BASE_URL` is set. Stats (parsed_ok / parse_failed / http_errors / timeouts) render. |
| **Analytics (30d)** | A list of `event_type → count` rows. After §1–§3 QA, at least `AUTH_LOGIN`, `POST_CREATED`, `REPLY_CREATED`, `ROOM_FOLLOWED`, `REPORT_CREATED`, `MEDIA_UPLOADED`, `EVENT_DETAIL_VIEWED` appear. |
| **Recent users** | List of latest registrations (30-day window). |
| **Recent rooms** | List of latest user-created rooms. |
| **Open report queue** | Lists open reports with reporter nickname + reason + age. |

### 4.4 Refresh button

1. Tap **새로고침** in the top bar.
2. **Expect:** all cards refetch; counts update if anything changed
   since last load (use the QA window's running counters as a sanity
   check).

### 4.5 Sign out

1. Tap **로그아웃**.
2. **Expect:** redirected back to the login form. localStorage no
   longer contains the token.

---

## 5. Media upload QA flow

Confirms `MEDIA_STORAGE_MODE=s3` is actually wired end to end. If
`MEDIA_STORAGE_MODE=local`, replace the bucket-verification step with
"verify the file exists on disk under `UPLOADS_DIR/`."

### 5.1 Upload via API

```bash
curl -sS -X POST \
  -H "Authorization: Bearer $MEMBER_TOKEN" \
  -F "file=@/path/to/sample.jpg" \
  https://<api-host>/v1/media/images | jq .
```

**Expect:**
```json
{
  "id": "<uuid>",
  "kind": "IMAGE",
  "filename": "sample.jpg",
  "mime_type": "image/jpeg",
  "size_bytes": <n>,
  "url": "https://<MEDIA_PUBLIC_BASE_URL>/<S3_OBJECT_PREFIX>/<uuid>.jpg",
  "created_at": "<iso8601>"
}
```

### 5.2 Verify the object is publicly fetchable

```bash
curl -sS -o /dev/null -w "%{http_code}\n" "<url-from-previous-response>"
# Expect: 200
```

If 403 or 404: check the bucket policy / `MEDIA_PUBLIC_BASE_URL` /
`S3_OBJECT_PREFIX`.

### 5.3 Verify the object exists in the bucket

In the cloud console (S3 / R2 / MinIO), navigate to
`<S3_BUCKET>/<S3_OBJECT_PREFIX>/<uuid>.jpg`. The object is present with
the expected mime type and size.

### 5.4 Negative cases

```bash
# Wrong mime type → 400
curl -sS -X POST -H "Authorization: Bearer $MEMBER_TOKEN" \
  -F "file=@/path/to/sample.pdf" https://<api-host>/v1/media/images
# Expect: 400 with "Unsupported MIME type"

# Oversize file → 400
# (create a 6MB file first)
curl -sS -X POST -H "Authorization: Bearer $MEMBER_TOKEN" \
  -F "file=@/path/to/big.jpg" https://<api-host>/v1/media/images
# Expect: 400 with "File too large"
```

### 5.5 Verify analytics captured the upload

```sql
SELECT actor_id, event_type, payload, created_at
FROM analytics_events
WHERE event_type = 'MEDIA_UPLOADED'
ORDER BY created_at DESC
LIMIT 1;
```

Payload includes `media_id`, `mime_type`, `size_bytes`, `storage_mode`.
It does NOT include `body`, `message`, `email`, or any user-typed text.

---

## 6. PRISM EVENT integration QA flow

Run only when `EVENTS_CLIENT_MODE=prism` AND
`PRISM_EVENTS_API_BASE_URL` is set. In `mock` mode the same calls
return the bundled fixture and the diagnostic stays at zeros.

### 6.1 Verify mode + base URL

```bash
curl -sS -H "Authorization: Bearer $ADMIN_TOKEN" \
  https://<api-host>/v1/admin/events-client/status | jq .
```

**Expect:**
```json
{
  "mode": "prism",
  "base_url_configured": true,
  "timeout_ms": 4000,
  "stats": {
    "parsed_ok": 0,
    "parse_failed": 0,
    "http_errors": 0,
    "timeouts": 0,
    "last_error": null,
    "last_error_at": null
  }
}
```

If `mode` is `mock`, check `EVENTS_CLIENT_MODE` env on the running pod.
If `base_url_configured` is false, `PRISM_EVENTS_API_BASE_URL` is
missing.

### 6.2 Trigger a real search

```bash
curl -sS -H "Authorization: Bearer $MEMBER_TOKEN" \
  "https://<api-host>/v1/events/search?q=<known-keyword>&status=UPCOMING" | jq .
```

**Expect:** `{"items": [...]}` with one or more rows. Each row has
`external_event_id`, `title`, `venue_name`, `region`, `starts_at`,
`event_status`, `thumbnail_url`.

### 6.3 Verify the diagnostic counter incremented

```bash
curl -sS -H "Authorization: Bearer $ADMIN_TOKEN" \
  https://<api-host>/v1/admin/events-client/status | jq .stats
```

`parsed_ok` is now > 0. `parse_failed` is still 0 (if upstream returns
clean rows) — or > 0 if some rows in the upstream response are
malformed.

### 6.4 Look up a single event

```bash
EVT_ID="<external-event-id-from-the-search>"
curl -sS -H "Authorization: Bearer $MEMBER_TOKEN" \
  "https://<api-host>/v1/event-cards/$EVT_ID" | jq .
```

Wait — `/v1/event-cards/:id` looks up by the **local** EventCard id,
not the external event id. To upsert a snapshot first:

```bash
curl -sS -X POST -H "Authorization: Bearer $MEMBER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"external_event_id\":\"$EVT_ID\"}" \
  https://<api-host>/v1/event-cards | jq .
```

Then use the returned local `id` to load the EventDetail bundle:

```bash
CARD_ID="<local-id-from-the-upsert>"
curl -sS -H "Authorization: Bearer $MEMBER_TOKEN" \
  "https://<api-host>/v1/event-cards/$CARD_ID" | jq .
```

**Expect:** `event_card`, `related_rooms`, `related_posts.items[]`,
`default_compose_room_slug`, `verified_reviews: []`, `counts`.

### 6.5 Failure-mode verification (optional, off-peak)

Repoint `PRISM_EVENTS_API_BASE_URL` at a host that returns 502:

```bash
# In the deployment platform: set PRISM_EVENTS_API_BASE_URL=https://httpstat.us
# Roll one pod. Wait for readiness.
curl -sS -H "Authorization: Bearer $MEMBER_TOKEN" \
  "https://<api-host>/v1/events/search?q=x" | jq .
# Expect: {"items":[]} — no 500, no exception.

curl -sS -H "Authorization: Bearer $ADMIN_TOKEN" \
  https://<api-host>/v1/admin/events-client/status | jq .stats
# Expect: http_errors > 0, last_error mentions the 502.
```

Revert the env after the check. Roll the pod once more so the
diagnostic resets.

---

## 7. Analytics verification flow

This must run **last**, after §1–§6, because it verifies the events
that those sections generated.

### 7.1 Summary endpoint

```bash
curl -sS -H "Authorization: Bearer $ADMIN_TOKEN" \
  https://<api-host>/v1/admin/analytics/summary | jq .
```

**Expect:**
```json
{
  "window_days": 30,
  "counts": [
    { "event_type": "AUTH_LOGIN", "count": ... },
    { "event_type": "POST_CREATED", "count": ... },
    ...
  ]
}
```

The QA flows should have produced at least one row of each:

| Event type | Generated by |
|---|---|
| `AUTH_LOGIN` | every login in §0.3, §1.1, §2.1, §3.1, §4.1 |
| `POST_CREATED` | §1.6, §1.7, §2.3 |
| `REPLY_CREATED` | §1.10 |
| `ROOM_FOLLOWED` | §1.5 |
| `ITEM_SAVED` | §1.11 |
| `ITEM_UNSAVED` | §1.11 (toggle off) |
| `NOTIFICATION_READ` | §1.10 |
| `REPORT_CREATED` | §1.9 |
| `MEDIA_UPLOADED` | §1.7, §5.1 |
| `EVENT_DETAIL_VIEWED` | §1.4, §6.4 |

If any of those are missing with a count of 0, the corresponding write
path is not emitting analytics — file a ticket, do NOT roll back unless
the underlying feature itself is broken (analytics emit is
fire-and-forget by design).

### 7.2 Per-event sanity check

For each event type the QA produced, verify the payload is privacy-
clean:

```sql
SELECT actor_id, event_type, payload, created_at
FROM analytics_events
WHERE event_type = 'POST_CREATED'
ORDER BY created_at DESC
LIMIT 5;
```

**Expect every payload to:**

- contain only the keys listed in [ANALYTICS.md](ANALYTICS.md) §2
- NOT contain `body`, `message`, `content`, `email`, `phone`,
  `password`, `token`, `access_token` (these are forbidden — `scrubPayload`
  drops them on write)
- contain no user-generated text (post body, reply body, profile bio)
- have string values ≤ 121 characters (120 + `…`)

Spot-check at least three event types. Failure on any one is a ticket;
sustained failure across event types is a SEV-2 (privacy regression).

### 7.3 Volume sanity

```sql
SELECT event_type, COUNT(*) AS n
FROM analytics_events
WHERE created_at >= NOW() - INTERVAL '1 hour'
GROUP BY event_type
ORDER BY n DESC;
```

Sanity check: the numbers should match roughly what the QA window
produced. If `AUTH_LOGIN` is dramatically larger than the rest, you
have a tight retry loop somewhere. If `AUTH_LOGIN` is zero, login isn't
emitting events — investigate.

### 7.4 No PII in `actor_id`

`actor_id` is a UUID (or NULL). Confirm:

```sql
SELECT DISTINCT actor_id FROM analytics_events
WHERE created_at >= NOW() - INTERVAL '1 hour';
```

Every value either matches a `users.id` UUID or is NULL. No email
addresses, no nicknames, no IPs.

---

## 8. Sign-off

Once §1–§7 all pass, mark the QA window complete:

- [ ] Cut-over log updated with timestamps + the test account UUIDs.
- [ ] Any non-blocking findings filed as tickets (severity tagged).
- [ ] Status page flipped to "Operational" (or kept on "Beta live"
      banner for the first 24 hours per launch comms plan).
- [ ] On-call partner signs off in the cut-over channel.

Refer to [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) §10 for the
post-launch follow-up tasks.
