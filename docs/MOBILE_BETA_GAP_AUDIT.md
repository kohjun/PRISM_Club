# PRISM Club — Mobile Beta Release Gap Audit

A single document inventorying what's left between today's tree and a
Play Internal-testing upload. Mobile work has shipped a lot of small
PRs (brand assets, Pretendard, visual smoke, signing template, etc.);
this doc consolidates **what's done**, **what's blocked on
operator action**, and **what still needs engineering** in one place
so release management has a single inventory to drive from.

> **Snapshot taken against commit `d195ac3 docs(mobile): add physical
> device qa log template` on 2026-05-20.** Re-run this audit before
> the first Play upload — the engineering rows below should still
> hold, but the operator-owned rows track real-world progress that
> drifts.

Pairs with:

- [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) — the
  full go/no-go list. This doc is the *summary*; the checklist is
  the *gate*.
- [ANDROID_RELEASE_DRY_RUN.md](ANDROID_RELEASE_DRY_RUN.md) —
  signing-state forensic snapshot.
- [ANDROID_RELEASE_IDENTITY_AUDIT.md](ANDROID_RELEASE_IDENTITY_AUDIT.md) —
  pre-asset gap snapshot (kept frozen as historical context).
- [PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md) — the Play
  Console flow the green rows below feed into.

---

## 1. Current green gates

Things that flutter / npm / git already confirm are healthy.

| Gate | Command | Current state |
|---|---|---|
| Static analysis | `cd apps/mobile && flutter analyze` | 4 pre-existing info-only items (`use_null_aware_elements` lints in four `data` repositories). No warnings, no errors. |
| Widget + unit tests | `cd apps/mobile && flutter test` | 133/133 green at HEAD. Covers visual smoke (core 6 + secondary 6 + empty/error 8), navigation context (topic hub back + composer round-trip), safe-route allow-list, fixtures across all sad-paths. |
| Debug APK | `cd apps/mobile && flutter build apk --debug` | Builds clean. |
| Release AAB (dry-run) | `cd apps/mobile && flutter build appbundle --release` | Builds (~42 MB, debug-signed fallback — expected per [ANDROID_RELEASE_DRY_RUN.md](ANDROID_RELEASE_DRY_RUN.md)). |
| Brand asset pipeline | `bash scripts/check-mobile-assets.sh` | 39/39 checks pass (legacy mipmaps + adaptive + monochrome + splash + theme wiring). Guards `flutter_launcher_icons` reinjecting `<inset>` after regen. |
| Release-signing structure | `bash scripts/check-release-signing.sh` | 8/8 structural checks pass (gitignore covers `key.properties` / `*.jks` / `*.keystore`; template is tracked; build.gradle.kts retains the `key.properties`-or-debug fallback and warning). NOTE-level on dry-run: `key.properties` absent on dev host (expected). |

---

## 2. Already closed (recent PR history)

Engineering work that flipped from open → closed since the design
handoff. Listed by the commit that closed it.

| Gap | Closed in |
|---|---|
| App identity (applicationId / namespace / app_name) | `464448e chore(mobile): set android app identity baseline` |
| Manifest permissions + url_launcher queries audited | `c352973 chore(mobile): audit android permissions` |
| Release signing template + Gradle fallback | `ca03bf4 chore(mobile): wire android release signing template` |
| Identity gap audit (sha1-evidenced placeholder PNG snapshot) | `98e6844 chore(mobile): audit android release identity` |
| Brand launcher icon (adaptive + monochrome + 5 legacy densities) + splash drawables | `2521b60 chore(mobile): land brand launcher icon and splash` |
| Brand asset drift guard (`scripts/check-mobile-assets.sh`) | `6ca3f92 chore(mobile): guard brand asset pipeline` |
| Play listing asset inventory + non-secret signing sanity check | `e0e5866 docs(mobile): prepare play internal testing assets` |
| Pretendard typography | `567d754 style(mobile): apply pretendard typography` |
| Touch-target hardening (follow CTA, composer remove buttons, StatusPill ellipsis) | `0b4f886 fix(mobile): harden design refresh touch targets` |
| Topic Hub back-fallback context (Home / Search / Profile / MyContributions entry) | `ff70863 fix(mobile): preserve topic hub return context` |
| Visual smoke coverage for core 6 screens (incl. 2 real Home overflows fixed) | `f7974c5 test(mobile): add visual smoke coverage for refreshed screens` |
| Home horizontal post strip safe for attached posts + scroll-aware sliver smoke | `ee0ce97 fix(mobile): cover attached posts and scrolled visual smoke` |
| Composer round-trip context (TopicHub → composer → cancel/submit → hub) | `deee930 fix(mobile): preserve topic hub return context through composers` |
| Visual smoke extended to 6 secondary screens (+ 1 real LoginPicker overflow fixed) | `53f706b test(mobile): extend visual smoke to secondary screens` |
| Empty / error / no-results visual state smoke | `af28011 test(mobile): cover empty and error visual states` |
| Physical-device QA log template | `d195ac3 docs(mobile): add physical device qa log template` |

The above is everything engineering can land without external
inputs. From here on, all forward motion needs either operator
material (a keystore, a privacy URL, screenshots) or a product
decision (push, crash reporting).

---

## 3. Remaining operator-owned gaps

Engineering can't land these. Each row is a checklist item that
belongs to release management, design, or legal — feeding their work
into the Play Console paperwork.

| Gap | Owner | Where to track | Notes |
|---|---|---|---|
| Real upload keystore generated + stored in vault | Release operator | [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) §4.1 | `keytool -genkey` one-time per app. Never commit the `.jks` — `scripts/check-release-signing.sh` enforces the gitignore. |
| `apps/mobile/android/key.properties` populated on release-build host | Release operator | [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) §4.1 + [ANDROID_RELEASE_DRY_RUN.md](ANDROID_RELEASE_DRY_RUN.md) §3 | Copy `key.properties.example` → `key.properties` and fill in real values. Build host only — not dev / CI. |
| Play App Signing enrolled at first upload | Release operator | [PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md) §2 | Recommended posture — makes upload-key compromise recoverable. |
| Play Console app created (Korean as default language, Free tier) | Release operator | [PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md) §6.1 | One-time. |
| Privacy policy URL (Korean primary) published at a stable URL | Legal + operator | [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) §6 | Draft answers in [PRIVACY_DATA_INVENTORY.md](PRIVACY_DATA_INVENTORY.md). Counsel-review before promoting beyond Internal. |
| Data Safety form filled to match server-side data inventory | Operator | [PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md) §8 | Draft answers shipped; verify against current code before submit. |
| Play listing screenshots (≥ 2 phone, ideally 7-inch tablet) captured from the installed Internal build | Operator | [PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md) §6.5 | Capture from the AAB on a real device, not the emulator. |
| Play listing copy (short + full description, what's-new) in Korean | Brand + operator | [PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md) §6.5 | Draft skeletons in the same section. |
| App category + tags chosen + contact email set | Operator | [PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md) §6.5 | Recommend `Social`. |
| Internal-testing tester group (email list or Google Group) + opt-in URL distributed | Operator | [PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md) §6.4 | ≤ 100 testers per Internal track. |
| At least 1 filled [MOBILE_DEVICE_QA_LOG.md](MOBILE_DEVICE_QA_LOG.md) per release-blocking device pass | QA | [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) §11 | Template shipped. Need ≥ 1 physical Pixel + ≥ 1 physical One UI / Galaxy log before Production promotion. |

---

## 4. Remaining engineering gaps

Things engineering still has to write code or make a product decision
on. Each row notes the blocker so it doesn't quietly sit.

| Gap | Status | What it needs | When |
|---|---|---|---|
| iOS scaffold (`apps/mobile/ios/`) | Not present | `flutter create --platforms=ios .` from a macOS host. Once landed, all the Android-only audits in §1 need parallel iOS rows (CFBundleIdentifier, App Privacy form, distribution provisioning, etc.). | Before any App Store submission. Out of scope for Play Internal. |
| Push notifications | Decision deferred | Pick Firebase + `firebase_messaging` vs. defer entirely for Beta. Server side has `INotificationDeliverer` boundary but `push` mode is a stub ([NEXT_BACKLOG.md](NEXT_BACKLOG.md) §2). | Decision before Production promotion. Internal / Closed beta is fine without it. |
| Crash reporting / structured analytics | Decision deferred | Sentry vs. Firebase Crashlytics vs. self-hosted vs. defer. App currently has no crash reporter wired. The Data Safety form's "Crash / diagnostic" answer is currently **No** — flipping it to Yes requires a wired SDK. | Decision before Production. Internal beta has logcat + the QA log template's crash-pull commands as a fallback. |
| Production `MEDIA_STORAGE_MODE` strategy | Decision deferred | Server-side picks between local disk (dev), S3, or another mode. Production target needs an explicit choice + a CDN / public-URL strategy. | Before Production. Affects `flutter build appbundle --release --dart-define=API_BASE_URL=…` smoke through the upload + thumbnail render path. |
| Production API base URL pinned | Pending | `MOBILE_RELEASE_CHECKLIST.md` §5 lists the target (`https://api.club.prism.app/v1`) but the DNS record + TLS termination need to be live before the first Production AAB ships. Internal / Closed track uses staging, no blocker. | Before Production. |
| `compileSdk` / `minSdk` / `targetSdk` explicitly pinned | ✅ Done | compileSdk = 36 (plugin set requires API 36); targetSdk = 35 (Play floor, one below compileSdk); minSdk left as `flutter.minSdkVersion` (resolves to 24, satisfies all plugin floors — Flutter Gradle tooling auto-reverts literal pins so we honor the SDK reference). See [ANDROID_RELEASE_IDENTITY_AUDIT.md](ANDROID_RELEASE_IDENTITY_AUDIT.md) §3.4 for the original gap and `apps/mobile/android/app/build.gradle.kts` for the pinned values. |
| Login picker swap (dev personas → real `/v1/auth/login` form) | Pending | Internal testing can keep the dev picker if testers know what to expect. Production needs the real form. ([NEXT_BACKLOG.md](NEXT_BACKLOG.md) §1) | Before Production. |
| Pretendard variable font binary | ✅ Verified | `apps/mobile/assets/fonts/PretendardVariable.ttf` (6,739,336 bytes) + `Pretendard-LICENSE.txt` both tracked in git. `pubspec.yaml` registers `family: Pretendard`. `buildPrismTheme()` sets `ThemeData.fontFamily = PrismFonts.body = 'Pretendard'` so inline `TextStyle` overrides inherit. Release AAB includes the binary at `base/assets/flutter_assets/assets/fonts/PretendardVariable.ttf` (verified via `unzip -l app-release.aab` in `docs(mobile): confirm pretendard binary presence`). |

---

## 5. Risk ranking

The gaps above grouped by what they block. Use this to prioritize the
remaining operator + engineering sequence.

### 5.1 Blocker — Play Internal upload cannot proceed without these

- Real upload keystore + `key.properties` (§3)
- Play Console app created + Play App Signing enrolled (§3)
- Privacy policy URL public (§3)
- Data Safety form filled (§3)
- ~~Explicit `targetSdk` pinned in `build.gradle.kts`~~ — done in `chore(mobile): pin android sdk versions for release` (compileSdk 36 + targetSdk 35)
- ~~Pretendard binary present in tree~~ — verified in
  `docs(mobile): confirm pretendard binary presence` (binary +
  license both tracked, registered in pubspec, bundled in AAB).

### 5.2 High — needed before Production promotion

- Push-notification decision (defer vs. wire) (§4)
- Crash reporting decision + (if Yes) wiring (§4)
- Production `MEDIA_STORAGE_MODE` + CDN strategy (§4)
- Production API base URL DNS + TLS live (§4)
- Login picker replaced with real `/v1/auth/login` (§4)
- ≥ 1 Pixel + ≥ 1 Galaxy physical QA log (§3)
- Play listing screenshots from installed Internal build (§3)
- Korean Play listing copy (§3)

### 5.3 Medium — quality bar, not gating

- 7-inch tablet screenshots (Production-only)
- App preview video (iOS, optional)
- iOS scaffold + everything that follows (§4 — separate workstream)

### 5.4 Low — nice-to-have

- Reduce / address the 4 baseline `use_null_aware_elements` info-only
  analyzer hints (not warnings; not blocking).
- Extend `expectNoOverflowWhileScrolling` to the four ListView-based
  screens (Home / Room / PostDetail / Profile) — currently only the
  two Sliver-based screens use the scrolling helper. Defensive.

---

## 6. Recommended next PR sequence

Engineering-side, in order. Each is small and independent.

1. ~~`chore(mobile): pin android sdk versions for release`~~ — done.
   compileSdk = 36, targetSdk = 35; minSdk left as
   `flutter.minSdkVersion` (= 24) because Flutter's Gradle tooling
   auto-reverts literal pins.
2. ~~`docs(mobile): confirm pretendard binary presence`~~ — done.
   Binary (6,739,336 bytes) + license tracked in git; pubspec
   registers `family: Pretendard`; theme + design tokens point at
   it; release AAB includes the font at
   `base/assets/flutter_assets/assets/fonts/PretendardVariable.ttf`.
3. **`test(mobile): extend scrolled smoke to home / room / post / profile`** —
   apply `expectNoOverflowWhileScrolling` to the four ListView-based
   screens that today only use the simpler helper. §5.4 defensive
   work; same pattern as the TopicHub / EventDetail extension.

Operator-side, in parallel:

4. Generate the upload keystore (§3 row 1) and create the Play Console
   app (§3 row 4).
5. Publish the privacy policy URL (§3 row 5) — engineering can review
   draft once legal lands.
6. Once steps 1–3 (engineering) and 4–5 (operator) are done, the
   first AAB can be cut + uploaded to Internal testing per
   [PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md).

After Internal is live, the §5.2 High row drives the path to
Production.

---

## 7. Go / no-go checklist for Play Internal Testing

A one-page recap of the gates Internal testing actually requires.
Everything in §5.1 must be green; §5.2 / §5.3 / §5.4 do **not** block
Internal.

- [ ] Engineering gates green (`flutter analyze` / `flutter test` /
      `mobile:check-assets` / `mobile:check-signing`).
- [x] `targetSdk` explicitly pinned (35 / Android 15) — done in the
      sdk-pin commit referenced in §6.1.
- [ ] `key.properties` populated on the release host; release AAB
      built with **no** `[prism-club] android/key.properties not found`
      warning.
- [ ] `keytool -list -printcert -jarfile app-release.aab` fingerprint
      matches the operator's upload key (not the debug keystore).
- [ ] `versionCode` strictly higher than any previous upload.
- [ ] Play Console app created; Play App Signing enrolled.
- [ ] Privacy policy URL public + listed in Play Console.
- [ ] Data Safety form filled against current code.
- [ ] App content sections all green in Play Console (App access,
      Ads, Content rating, Target audience).
- [ ] ≥ 2 phone screenshots uploaded.
- [ ] Short + full description in Korean.
- [ ] At least 1 filled [MOBILE_DEVICE_QA_LOG.md](MOBILE_DEVICE_QA_LOG.md)
      with verdict SUBMIT against the AAB you're about to upload.
- [ ] Tester group created + opt-in URL ready to distribute.

Tick → upload → smoke from a tester device via the opt-in URL →
promote to Closed / Open / Production through the same console once
the §5.2 row clears.

Track each row's status as it changes — this doc is the single page
release management reads before pressing "Start rollout". When all
boxes are checked, the §5.1 risk surface is exhausted and the first
Internal AAB is safe to upload.
