# PRISM Club — Mobile QA Script

The repeatable QA checklist for testers running PRISM Club on
**Android emulator** and **physical Android devices** against the
local NestJS API. iOS additions land alongside the iOS scaffold (see
[FLUTTER_NATIVE_SETUP.md](FLUTTER_NATIVE_SETUP.md) §3).

> **Audience.** Testers and PMs running through a release candidate
> on real hardware. Developers should also use this script before
> shipping any PR that touches the mobile surface.

Pairs with:

- [LOCAL_BROWSER_QA.md](LOCAL_BROWSER_QA.md) — same flows, but in
  Chrome on `localhost` (faster developer feedback loop)
- [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md) — the production-shaped
  cut-over QA script
- [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) — store
  submission go/no-go
- [FLUTTER_NATIVE_SETUP.md](FLUTTER_NATIVE_SETUP.md) — emulator +
  device commands

---

## 1. Setup

### 1.1 Local backend (one-shot)

Before starting any device flow, bring up the local API per
[LOCAL_BROWSER_QA.md](LOCAL_BROWSER_QA.md) §2:

```bash
# From the repo root, in separate terminals:
docker compose up -d postgres
npx prisma migrate dev
npm run db:seed
npm run api:dev          # http://localhost:3000/v1
```

Sanity-check before launching the app:

```bash
curl -sS http://localhost:3000/v1/health           # → {"ok":true}
curl -sS http://localhost:3000/v1/health/ready     # → {"ok":true,"db":"up"}
curl -sS http://localhost:3000/v1/health/version | jq .
```

### 1.2 Decide which device

Three QA modes; pick the one you need today.

| Mode | Use when |
|---|---|
| **Android emulator** | First QA pass for a PR; reproducing a bug; no physical device handy |
| **Physical Android device** | Release candidate sign-off; testing real network conditions, secure storage, file picker |
| **iOS** | After macOS engineer adds the `ios/` scaffold ([FLUTTER_NATIVE_SETUP.md](FLUTTER_NATIVE_SETUP.md) §3) |

---

## 2. Android emulator QA flow

### 2.1 Boot the emulator

```bash
cd apps/mobile
flutter pub get          # first run only
flutter emulators              # list configured AVDs
flutter emulators --launch <emulator-id>
flutter devices                # confirm the emulator appears
flutter run -d <device-id>     # launches the app with hot reload
```

The default `apiBaseUrl` on Android emulator is `http://10.0.2.2:3000/v1`
— no `--dart-define` needed. The emulator routes `10.0.2.2` to the host
machine's `localhost`.

### 2.2 Smoke probes

Before walking the QA sections, verify the emulator can reach the API:

- [ ] Login picker renders within 5 seconds of launch.
- [ ] No connection-refused banner / red error screen.

If the login picker shows but every persona tile triggers a "failed
to login" toast, the emulator can't reach the API. Confirm:

```bash
adb shell ping -c 1 10.0.2.2     # should succeed
adb shell wget -qO- http://10.0.2.2:3000/v1/health   # → {"ok":true}
```

---

## 3. Physical device QA flow

### 3.1 Prerequisites

- [ ] USB debugging on (Settings → Developer options → USB debugging).
- [ ] Device shows up in `flutter devices`.
- [ ] Laptop and device on the **same Wi-Fi network**.
- [ ] Laptop firewall allows inbound TCP 3000 from the LAN
      (Windows Defender / macOS firewall may block by default).

### 3.2 Find your laptop's LAN IP

```bash
# Windows
ipconfig | findstr IPv4

# macOS / Linux
ifconfig | grep "inet " | grep -v 127.0.0.1
```

Pick the IP on your active network (e.g. `192.168.1.42`).

### 3.3 Launch the app

```bash
cd apps/mobile
flutter pub get
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=http://<lan-ip>:3000/v1
```

The override is mandatory — the default `localhost:3000/v1` resolves
to the **device's own loopback**, which has nothing on port 3000.

### 3.4 Smoke probes

- [ ] App boots; login picker renders within 5 seconds.
- [ ] Personas list populated (the API call succeeded over LAN).
- [ ] DevTools (`flutter logs`) shows no network errors.

If the login picker is empty:

```bash
adb logcat | grep -i "dio\|http\|prism"   # see request errors
```

Likely fixes: firewall on the laptop blocking 3000, or the API
binding only to `127.0.0.1` (it shouldn't — NestJS binds `0.0.0.0` by
default).

---

## 4. Login / session restore

Same on emulator and physical device unless noted.

### 4.1 Login

- [ ] Tap **민서 (minseo)** in the login picker.
- [ ] App navigates to `/home` within ~2 seconds.
- [ ] Top of `/home` shows the unread notification count (badge ≥ 0).

### 4.2 Session persists across cold launch (the secure-storage check)

- [ ] Background the app (Home button), then force-stop via
      Settings → Apps → PRISM Club → Force stop.
- [ ] Re-launch the app.
- [ ] **Expected:** lands on `/home`, NOT the login picker. The JWT
      was restored from secure storage (Android Keystore-backed
      `EncryptedSharedPreferences`).

### 4.3 Sign out

- [ ] Bottom nav → **커뮤니티** → AppBar **로그아웃**.
- [ ] App navigates to login picker.
- [ ] Force-stop + relaunch → still on login picker (storage was
      cleared).

---

## 5. Home / search / Topic Hub

### 5.1 Home

- [ ] `/home` renders sections in order (some may be empty for a
      fresh persona):
  - followed-room updates
  - recommended rooms
  - recommended events
  - trending posts
  - active topic hubs
  - recent saves
- [ ] Pull-to-refresh works (drag down from the top).
- [ ] Tapping any card navigates to the corresponding screen.

### 5.2 Search

- [ ] Bottom nav → **검색** opens the search screen.
- [ ] Empty state shows popular topic chips.
- [ ] Query "환승연애" returns multiple groups (Topic Hub, knowledge
      block, room, post, event card, reference).
- [ ] Chip filter narrows to a single group.
- [ ] Query "" (empty) shows the empty state again.

### 5.3 Topic Hub

- [ ] Bottom nav → **커뮤니티** → 참가자 → 연애 콘텐츠.
- [ ] Topic Hub renders: blocks, signals, related events, related
      references, related rooms.
- [ ] Related event tile tap → `/events/<cardId>`.
- [ ] Reference tile tap → opens external browser (verifies
      `url_launcher` + Android 11+ queries from the permission
      audit).

---

## 6. Room / post / reply

### 6.1 Room timeline

- [ ] Topic Hub → 환승연애식 오프라인 토크 게임 room → timeline
      renders.
- [ ] Tap **팔로우** in AppBar → button flips to **팔로잉**, count
      increments.
- [ ] Refresh → follow state persists.

### 6.2 Compose text post

- [ ] FAB → composer opens.
- [ ] Type `mobile QA test post <timestamp>`.
- [ ] Submit → new post appears at the top of the timeline within
      ~2 seconds.

### 6.3 Reply

- [ ] Tap the post you just created.
- [ ] Tap **댓글 작성** input → type `reply check`.
- [ ] Submit → reply appears under the post.
- [ ] Tap **답글** on the reply → nested reply (depth 2) input
      opens.
- [ ] Submit → nested reply appears indented under the parent.
- [ ] Attempt depth 3 by tapping **답글** on the nested reply →
      input is disabled OR the API returns 400. **Either is
      acceptable** but it must NOT silently submit.

### 6.4 Like / unlike

- [ ] Tap the like icon on a post → fill state + count +1.
- [ ] Tap again → empty state + count -1.

---

## 7. Event detail

- [ ] From the 연애 콘텐츠 Topic Hub, tap a related event.
- [ ] `/events/<cardId>` renders: hero card, "관련 방", "관련 글",
      counts at the bottom.
- [ ] Tap **글 작성** FAB → composer opens with the EventCard
      pre-attached under "첨부된 이벤트".
- [ ] Remove the attachment via the X → it disappears from the
      composer.
- [ ] Cancel composer → back to `/events/<cardId>`.

---

## 8. Save / follow / notification

### 8.1 Save

- [ ] On any post detail → tap bookmark icon → icon fills.
- [ ] Bottom nav → **저장** → the post appears under the POST chip.
- [ ] Filter chip → REFERENCE → seeded references appear.
- [ ] Filter chip → EVENT_CARD → seeded event cards appear.
- [ ] Tap a saved item → navigates to the corresponding detail.
- [ ] Toggle bookmark off → item disappears from saves on next pull-
      refresh.

### 8.2 Follow

- [ ] Already covered in §6.1 (room follow).
- [ ] On a post author's profile (tap author avatar): **팔로우** →
      button flips, count increments.

### 8.3 Notification

To exercise the unread flow you need two personas. Use the second
ones already seeded.

- [ ] Sign out → log in as **joon** → reply to minseo's post from
      §6.2.
- [ ] Sign out → log in as **민서** → bottom nav **알림** shows the
      new `REPLY_ON_POST` entry; unread badge ≥ 1.
- [ ] Tap the entry → marked read, badge decrements, route lands on
      the parent post.

---

## 9. Profile / edit profile

- [ ] Tap a post author → `/users/<id>` profile renders with role
      badges (where applicable), counts, recent posts, owned rooms,
      approved contributions.
- [ ] On **your own** profile, AppBar shows **⋯** menu →
      **프로필 편집**.
- [ ] Edit sheet opens. Modify bio, region, interests.
- [ ] Save → sheet closes, profile re-renders with the new values.
- [ ] On another user's profile, AppBar **⋯** menu is NOT visible.
- [ ] Tap **팔로우** on another user → button flips to **팔로잉**.

---

## 10. Media upload

The Android-specific path uses `file_picker` with the Storage Access
Framework. No runtime permission prompt should appear (SAF handles
its own picker UI).

- [ ] Open the post composer in any room.
- [ ] Tap the image picker icon.
- [ ] **Expected:** Android SAF "Recent files" / "Photos" picker
      opens. **NO** "Allow PRISM Club to access photos and media?"
      prompt — that prompt only appears with `READ_MEDIA_IMAGES`
      permission, which we deliberately do not request.
- [ ] Pick a sample JPG / PNG / WEBP / GIF under 5 MB.
- [ ] Preview thumbnail appears in the composer.
- [ ] Submit → post appears in the timeline with the image rendered.
- [ ] Verify oversize rejection: pick a > 5 MB file → toast says
      "File too large" (or similar). Post is NOT created.
- [ ] Verify wrong MIME rejection: pick a `.pdf` (rename a text file
      if needed) → toast says "Unsupported MIME type".

---

## 11. Moderator / admin / negative paths

If the device is signed in as **coral** (CURATOR + MODERATOR):

- [ ] SpaceList shows **검수 큐로 가기** + **운영 대시보드** banners.
- [ ] **운영 대시보드** → `/admin/ops` counters render.
- [ ] **시그널 새로고침** → success snackbar.
- [ ] `/admin/reports` → open report → resolve with HIDE → reported
      post disappears from timelines / search / `/home`.
- [ ] `/curate` → APPROVE pending contribution → block content
      updates.

If signed in as a plain member, **none of those surfaces are reachable**:

- [ ] SpaceList banners are absent.
- [ ] Manually navigating to `/admin/ops` shows a 403-shaped error,
      not a populated dashboard.

If signed in as **studio_lead** (VERIFIED_PLANNER):

- [ ] 기획자 스튜디오 unlocks (no lock dialog).
- [ ] **모집 글쓰기** FAB → RecruitmentComposer → submit → new post
      visible in timeline + search.
- [ ] Status chip toggle: OPEN → CLOSED → FILLED on own posts only.

---

## 12. Reset / troubleshooting

### Reset app data on device

Long-press the launcher icon → **App info** → Storage → **Clear
storage**. Or:

```bash
adb shell pm clear club.prism.mobile
```

Wipes shared preferences + secure storage + cached data. Next launch
shows the login picker.

### Reset the local DB (laptop)

```bash
npm run db:reset
```

Drops + recreates `prism_club`, applies migrations, runs the seed.

### Force-uninstall after a debug build crash loop

```bash
adb uninstall club.prism.mobile
flutter run -d <device-id> --dart-define=API_BASE_URL=...
```

### `flutter run` says "Adb is not running"

```bash
adb kill-server
adb start-server
```

### Emulator shows "Connection refused"

The API isn't running on the laptop, or the emulator's `10.0.2.2`
isn't reachable. Test with:

```bash
adb shell curl -sS http://10.0.2.2:3000/v1/health
```

If that fails but `curl http://localhost:3000/v1/health` works on the
laptop, you're hitting a firewall rule. On Windows, allow port 3000
through Windows Defender Firewall (`wf.msc` → Inbound rules).

### Physical device login picker is empty

Same diagnosis as §3.4 — the device can't reach the laptop API. Check
the LAN IP, firewall, and that the API binds to `0.0.0.0` (NestJS
default).

### Hot reload doesn't apply

Press `R` in `flutter run` for a full hot **restart**. If that doesn't
work, kill `flutter run` and re-launch.

---

## 13. Sign-off

Fill this block in the QA ticket attached to the release candidate:

```
PRISM Club — Mobile QA Sign-off
================================
Date / tester              : <YYYY-MM-DD / name>
Build commit               : <git sha>
APK / AAB                  : <path or SHA-256>

Target
  Device                   : <emulator name | physical model + Android version>
  --dart-define API_BASE_URL: <value>

Sections (PASS / FAIL — notes)
  §2 Emulator boot         : <PASS / FAIL>
  §3 Physical device boot  : <PASS / FAIL>
  §4 Login + session restore : <PASS / FAIL>
  §5 Home / search / Topic Hub : <PASS / FAIL>
  §6 Room / post / reply   : <PASS / FAIL>
  §7 Event detail          : <PASS / FAIL>
  §8 Save / follow / notification : <PASS / FAIL>
  §9 Profile / edit profile : <PASS / FAIL>
  §10 Media upload (SAF, no perm prompt) : <PASS / FAIL>
  §11 Moderator / planner / member negatives : <PASS / FAIL>

Issues filed              : <ticket links, or "none">

Verdict                   : <READY for release | NOT READY>
Signed                    : <name + date>
```

`READY for release` means every section passes AND any FAIL has been
filed as a ticket AND a non-blocker. Otherwise NOT READY — fix → ticket
→ re-run the affected sections.
