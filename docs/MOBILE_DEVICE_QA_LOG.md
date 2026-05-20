# PRISM Club — Mobile Device QA Log Template

A fill-in-the-blanks log for capturing a single physical-device QA
pass. Copy this template into a release ticket (or a per-device
markdown file under `qa-logs/` if your team keeps them in-repo), then
fill it in as you exercise the build.

Pairs with:

- [MOBILE_QA_SCRIPT.md](MOBILE_QA_SCRIPT.md) — the action script
  testers walk through.
- [ANDROID_DEVICE_RUNBOOK.md](ANDROID_DEVICE_RUNBOOK.md) — how to get
  the build onto the device in the first place.
- [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md) — pre-promotion gate on top
  of MOBILE_QA_SCRIPT.
- [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) §11 —
  the gate the filled log unblocks.

> **Why this template exists.** The QA script tells you what to
> tap. The runbook tells you how to install. Neither gives you a
> shape for the *answer* — what passed, what failed, on which
> device, with which build SHA — that release management needs to
> sign off. This doc is that shape.

---

## 1. Purpose

A single QA log entry captures *one device × one build*. If you test
two devices against the same build, file two logs. If you test the
same device against two builds, file two logs. This makes the data
easy to triage later — every row is a fixed point.

The log is not a script. It tracks **what you ran**, **what you
saw**, and **what to do next**. Run the script
([MOBILE_QA_SCRIPT.md](MOBILE_QA_SCRIPT.md) /
[BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md)) in parallel; transcribe the
results here.

---

## 2. Before you start

- [ ] API is up. Pick one:
  - **Local**: `npm run api:dev` (default `http://localhost:3000/v1`)
    — only works when the device can reach the dev host
    (emulator: `10.0.2.2`; physical device: dev box LAN IP).
  - **Staging**: `https://api.staging.<your-domain>/v1` —
    Internet-reachable from the device, no LAN dance.
- [ ] Build is reachable on the device:
  - **Debug APK**: `flutter build apk --debug` then
    `adb install -r app-debug.apk` (or Internal testing track in
    Play Console for non-developer testers).
  - **Release AAB**: only via Play Internal testing — see
    [PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md) §6.3.
- [ ] `--dart-define=API_BASE_URL=...` was passed at build time and
      points at the API you intended. Quick verification: from inside
      the installed app, the login picker should populate dev users;
      if it spins on "사용자 목록 로딩 중…" or errors, the API URL is
      wrong.
- [ ] Build SHA captured: `git rev-parse --short HEAD` at the time
      of `flutter build`. Paste into §3 below.
- [ ] Screenshot / screen-record folder ready on your laptop.
      Convention: `qa-logs/<YYYY-MM-DD>-<device>-<short-sha>/`.

---

## 3. Device under test

| Field | Value |
|---|---|
| Tester | <name> |
| Date | <YYYY-MM-DD> |
| Manufacturer / model | <Samsung Galaxy S23 / Pixel 7a / etc.> |
| Android version | <14 (One UI 6.0) / 13 (stock AOSP) / etc.> |
| Screen size | <6.1" / 6.7" / etc.> |
| Screen resolution | <1080 × 2340 / 1440 × 3120 / etc.> |
| Effective dp width | <360 / 384 / 412 / 430 / 480 / etc.> |
| Network | <Wi-Fi (corp) / LTE / 5G> |
| Build artifact | <app-debug.apk / app-release.aab via Play> |
| Build SHA | <git short SHA at build time> |
| `versionName` / `versionCode` | <0.1.0 / 1> |
| API target | <localhost / staging / production> |

Fill the table BEFORE tapping anything — it sets the scope of
everything below.

---

## 4. Smoke checklist (common path)

Tick each as it passes; leave blank + add a §7 row for any failure.

### 4.1 Install + first launch

- [ ] APK installs without "Play Protect" rejection.
- [ ] Launcher icon shows the brand mark (purple prism), not the
      Flutter "F" — see
      [APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md) for the
      expected look.
- [ ] App label reads "PRISM Club" on the home grid.
- [ ] Cold launch → splash → login picker, no visible white
      flash on the way to the first Flutter frame.

### 4.2 Auth + session

- [ ] Login picker lists ≥ 1 dev persona.
- [ ] Tap a persona → land on `/home`.
- [ ] Force-close the app from recents → reopen → still logged in
      (JWT persisted via secure storage).
- [ ] Sign out → reopen → login picker shown.

### 4.3 Core surfaces

Tap through each. Verify the screen renders, scrolls, and the back
button gets you out:

- [ ] Home (feed + topic hub strip).
- [ ] Topic Hub (hero + knowledge blocks + events + references +
      rooms section).
- [ ] Room timeline (post cards + FAB).
- [ ] Post detail (body + replies + composer).
- [ ] Event detail (gradient hero + date card + related rooms).
- [ ] Profile (hero + counts + recent posts).

### 4.4 Cross-cutting

- [ ] Search (tap the search icon, type a Korean query, see
      grouped results).
- [ ] Saves tab (filter chips render, type filter works).
- [ ] Notifications tab (grouped list, mark all read works).
- [ ] Pull-to-refresh on each scrollable surface.

### 4.5 Media + external

- [ ] Image upload: pick an image > 2 MB, attach, post — thumbnail
      renders after the room reloads.
- [ ] External Reference link: tap a Reference URL on a Topic Hub
      → OS browser opens (verifies the `url_launcher` package-
      visibility queries shipped in the release manifest).
- [ ] Bottom nav: each tab opens its primary screen.

### 4.6 Back-stack + navigation

- [ ] Home → tap a Topic Hub card → tap back → return to Home (not
      `/spaces`).
- [ ] CategoryList → Topic Hub → back → return to the same space's
      category list.
- [ ] Search → tap a result → back → return to the same query in
      the search input.
- [ ] Topic Hub → tap "정보 개선 제안" → close → back from the hub
      returns to the original origin (Home / Search / Profile).

### 4.7 Orientation + lifecycle (if applicable)

- [ ] Rotate to landscape (if the app supports it). Note in §7 if
      any screen breaks. PRISM Club is portrait-first today; landscape
      regressions are nice-to-fix, not blockers.
- [ ] Home button → wait ~10 minutes → return. App resumes (or
      cold-restart on low-RAM devices) without losing the session.

---

## 5. Visual QA

A focused visual sweep at 360dp / 430dp / your-device-width. Tick
each; record any failure in §7 with a screenshot path.

- [ ] No yellow-and-black overflow stripes on any rendered screen.
- [ ] No clipped text — Korean labels in cards / chips / tabs /
      AppBar end with ellipsis when truncated, not mid-syllable cut.
- [ ] All tappable controls ≥ 44dp touch target — buttons, FAB,
      chips, IconButtons.
- [ ] Keyboard does not overlap the active input on PostComposer,
      ContributionComposer, RoomCreator, Search input.
- [ ] Safe area respected (notch, gesture bar) — no content slips
      under the bottom nav or the top status bar.
- [ ] FAB / sticky CTAs do not occlude the bottom row of content.
- [ ] Splash background matches the brand (`#6D28D9`) on cold
      launch — no white flash.
- [ ] Adaptive icon renders correctly on Android 8+ launchers
      (circle on Pixel, squircle on One UI). Long-press the icon
      to confirm the OEM mask shape.
- [ ] Dark-mode launcher icon (Android 13+) shows the monochrome
      brand mark when the user has themed icons on.

---

## 6. Log capture

Capture parallel evidence so a triage owner can reproduce the issue.

### 6.1 adb logcat

While the issue is reproducing, on the laptop:

```
adb logcat -s flutter:* -s "club.prism.mobile:*"
```

Pipe to a file if the issue is intermittent:

```
adb logcat -s flutter:* > qa-logs/<date>-<device>-<sha>/logcat.txt
```

### 6.2 flutter logs

For debug builds running through `flutter run`:

```
flutter logs -d <device-id>
```

(`flutter devices` lists the IDs.)

### 6.3 Screenshots / screen recording

- Single frame: `adb exec-out screencap -p > screen.png`.
- Recording: `adb shell screenrecord /sdcard/run.mp4` — hit Ctrl-C
  to stop, then `adb pull /sdcard/run.mp4`.
- File name convention:
  `<YYYY-MM-DD>-<short-sha>-<device>-<screen>-<seq>.png`,
  e.g. `2026-05-20-ee0ce97-pixel7a-topichub-overflow-01.png`.

### 6.4 Crash / ANR

If the app force-closes:

```
adb logcat -d -b crash > qa-logs/<date>-<device>-<sha>/crash.txt
adb logcat -d -b system | grep -i ANR > qa-logs/.../anr.txt
```

Attach both to the issue.

---

## 7. Issues found

For every failed check above, log a row. Sort by severity, then by
the screen. Keep one row per defect — if the same defect blocks two
screens, list both screens in the row.

| # | Severity | Device | Screen(s) | Reproduction | Screenshot | Owner | Status |
|---|---|---|---|---|---|---|---|
| 1 | <BLOCKER / HIGH / MED / LOW> | <Pixel 7a / Android 14> | <HomeScreen / TopicHubScreen> | <1. tap …; 2. observe …; expected …; actual …> | <qa-logs/…/file.png> | <triage owner> | <OPEN / FIXED / DUPLICATE / WONTFIX> |
| 2 | … | … | … | … | … | … | … |

Severity rubric:

- **BLOCKER** — first-launch crash, login broken, post submit fails
  with no error message, data loss.
- **HIGH** — common path renders wrong (overflow, untappable
  control, wrong screen on back).
- **MED** — visual polish on a real-but-rare path (long Korean
  nicknames, full attachment row, dark-mode themed icon).
- **LOW** — copy nits, single-pixel misalignment, debug-only
  warnings in logcat.

---

## 8. Sign-off

Fill once all checks have a result.

```
PRISM Club — Mobile Device QA Sign-off
======================================
Device                : <make + model>
Android version       : <version + OEM skin>
Build SHA             : <short SHA>
versionName / code    : <0.1.0 / 1>
API target            : <localhost / staging / production>
Tester                : <name>
Date                  : <YYYY-MM-DD>

Smoke checklist       : <PASS / FAIL (N items)>
Visual QA             : <PASS / FAIL (N items)>
Issues found          : <count, severity rollup>
Blocking issues       : <list IDs, or "none">
Attachments           : <logcat path, screenshots path, recording path>

Verdict               : <SUBMIT / HOLD>
Promote to            : <Internal / Closed / Open / Production / N/A>

Signed                : <name + date>
```

Verdict **SUBMIT** unblocks
[MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) §11
"At least one **physical Android device** pass". One signed log per
device-build combination satisfies the gate.

Verdict **HOLD** → triage the §7 issues → re-test → file a new log
on the next build. Don't edit a HOLD log in place; logs are
historical evidence and edits muddle the audit trail.
