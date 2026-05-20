# PRISM Club — Mobile Release Checklist

The discrete go / no-go list for the first **App Store** / **Play
Store** upload of PRISM Club. Consolidated state across all gates
(done / blocked on operator / still engineering) lives in
[MOBILE_BETA_GAP_AUDIT.md](MOBILE_BETA_GAP_AUDIT.md); this file is
the per-row gate. Pairs with
[FLUTTER_APP_RELEASE_AUDIT.md](FLUTTER_APP_RELEASE_AUDIT.md) (the
inventory) and [FLUTTER_NATIVE_SETUP.md](FLUTTER_NATIVE_SETUP.md)
(the day-to-day commands).

> **Scope.** Native Flutter app release — Android (Play) + iOS (App
> Store / TestFlight). Web is local QA only
> ([LOCAL_BROWSER_QA.md](LOCAL_BROWSER_QA.md)); staging is the cut-over
> rehearsal venue ([STAGING_BRINGUP_CHECKLIST.md](STAGING_BRINGUP_CHECKLIST.md)).

> **This file does not change product code.** Each box maps to an
> existing PR sequence item from the audit or to store paperwork.

---

## 1. Android — package / applicationId

Snapshot re-verified in
[ANDROID_RELEASE_IDENTITY_AUDIT.md](ANDROID_RELEASE_IDENTITY_AUDIT.md) §2.

- [x] `applicationId = "club.prism.mobile"` set in
      `android/app/build.gradle.kts`. Will be locked once the first
      AAB is uploaded to Play.
- [x] `namespace = "club.prism.mobile"` matches.
- [x] `android:label` resolves through `@string/app_name` (defined in
      `android/app/src/main/res/values/strings.xml` as **"PRISM
      Club"**), not hardcoded to the Flutter default `"mobile"`.
- [ ] `versionCode` and `versionName` derive from
      `apps/mobile/pubspec.yaml` `version:` (currently `0.1.0+1`).
      Bumped per release: `0.1.0+1` → `0.1.0+2` → `0.1.1+3` etc. —
      bump rules, RC tagging, and rollback warnings live in
      [MOBILE_VERSIONING.md](MOBILE_VERSIONING.md).
- [ ] `compileSdk` + `targetSdk` pinned explicitly to the current Play
      target (34 today). Do NOT rely on `flutter.targetSdkVersion`
      for the release build.
- [ ] `minSdk` set to the value the team has agreed to support.
      Currently `flutter.minSdkVersion` (21). Lock or bump
      deliberately.
- [ ] Java + Kotlin target = 17 (already pinned).

Files:
[`apps/mobile/android/app/build.gradle.kts`](../apps/mobile/android/app/build.gradle.kts)
+ [`apps/mobile/pubspec.yaml`](../apps/mobile/pubspec.yaml).

---

## 2. iOS — bundle identifier

- [ ] `apps/mobile/ios/` scaffold exists (currently MISSING — needs
      `flutter create --platforms=ios .` on macOS per
      [FLUTTER_NATIVE_SETUP.md](FLUTTER_NATIVE_SETUP.md) §3).
- [ ] `CFBundleIdentifier = club.prism.mobile` (matches Android
      applicationId).
- [ ] `CFBundleDisplayName = "PRISM Club"`.
- [ ] `CFBundleShortVersionString` (e.g. `0.1.0`) and
      `CFBundleVersion` (build number, e.g. `1`) wired to the same
      `pubspec.yaml` `version:` source as Android.
- [ ] `MinimumOSVersion` set to the team-agreed iOS floor (Flutter
      currently defaults to iOS 12.0; iOS 13.0+ unlocks SwiftUI
      interop if needed later).

---

## 3. App icon / splash

**Current state:** Brand launcher icon + adaptive icon (background +
foreground + Android 13+ monochrome) + splash drawables are landed.
Sources live in `apps/mobile/assets/branding/`; Android resources were
regenerated via `flutter_launcher_icons` + `flutter_native_splash`.
Pre-asset gap snapshot is preserved in
[ANDROID_RELEASE_IDENTITY_AUDIT.md](ANDROID_RELEASE_IDENTITY_AUDIT.md)
§3 for historical context.

Full pipeline (source files, sizes, adaptive icon XML, generation
commands, QA checklist): see
[APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md). This checklist tracks
go/no-go; the pipeline doc tells the design owner / operator exactly
what to hand off and how to regenerate every platform artefact from
one source. Point-in-time audit of which Android paths are still on
the Flutter placeholder (with sha1s + dimensions) is in
[ANDROID_RELEASE_IDENTITY_AUDIT.md](ANDROID_RELEASE_IDENTITY_AUDIT.md)
§3.

- [x] Branded launcher icon replaces the default Flutter "F" mark on
      Android (all `mipmap-*` densities) — see audit §8.
- [x] Adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml` +
      `ic_launcher_foreground` + `ic_launcher_background` +
      `ic_launcher_monochrome` for Android 13+ themed icons).
- [x] Android launch background updated (`drawable/launch_background.xml`
      + `drawable-v21/` + `values-v31/styles.xml` for the Android 12+
      splash-screen API).
- [ ] iOS app icon set generated in `ios/Runner/Assets.xcassets/
      AppIcon.appiconset/` — all required sizes. (Blocked on iOS
      scaffold — see FLUTTER_NATIVE_SETUP.md §3.)
- [ ] iOS launch storyboard reviewed (Flutter default is acceptable
      for Beta).
- [x] Generated via `flutter_launcher_icons` and
      `flutter_native_splash` for reproducibility (config blocks in
      `pubspec.yaml`, one `dart run` per asset refresh).

**Operator refresh** (when the brand source files change):

1. Drop the new source SVG/PNG into `apps/mobile/assets/branding/`.
2. If the foreground or background changed, regenerate the
   `app_icon_legacy.png` composite — see
   [APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md) §8 for the one-liner.
3. `dart run flutter_launcher_icons` + `dart run flutter_native_splash:create`.
4. Hand-restore `mipmap-anydpi-v26/ic_launcher.xml` to the no-inset
   variant — the plugin reinjects 16% insets every run; see
   [APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md) §8.
5. Commit the regenerated `android/app/src/main/res/` files alongside
   the new source.

### Typography

**Current state:** Pretendard is bundled as a variable font at
`apps/mobile/assets/fonts/PretendardVariable.ttf` and registered as the
app-wide Flutter `fontFamily`. The upstream license is preserved next to
the binary at `apps/mobile/assets/fonts/Pretendard-LICENSE.txt`.

- [x] `pubspec.yaml` registers `family: Pretendard`.
- [x] `buildPrismTheme()` applies Pretendard as the app-wide font.
- [x] Body / caption / label tracking remains near zero for Korean
      readability; tighter negative tracking is limited to larger
      display / title styles.
- [ ] Physical-device QA confirms Korean text renders without tofu /
      missing-font squares across the persona walkthrough.

---

## 4. Signing

### 4.1 Android upload key

Dry-run state today: both `flutter build apk --release` and
`flutter build appbundle --release` succeed at HEAD but produce
**debug-signed** artifacts that Play rejects. See
[ANDROID_RELEASE_DRY_RUN.md](ANDROID_RELEASE_DRY_RUN.md) for the full
inventory of what works and what's missing.

- [ ] Keystore file generated (`keytool -genkey -v ...`) and stored
      in the team password vault. **Do NOT commit.**
- [ ] `android/key.properties` (gitignored) lists `storeFile`,
      `storePassword`, `keyAlias`, `keyPassword`. Copy
      `android/key.properties.example` as the starting point.
- [x] `android/app/build.gradle.kts` `signingConfigs.release` reads
      from `key.properties` and `buildTypes.release.signingConfig`
      picks the release config when present, falling back to debug
      with a Gradle warning when absent — see
      ANDROID_RELEASE_DRY_RUN §3.3.
- [x] `npm run mobile:check-signing` confirms gitignore covers
      `key.properties` / `*.jks` / `*.keystore`, the `.example`
      template is tracked, and the `key.properties`-or-debug wiring
      is intact (8 structural checks; absence of `key.properties` on
      this host reports as NOTE, not FAIL).
- [ ] Play App Signing enabled in the Play Console so we only manage
      the upload key.

### 4.2 iOS provisioning

- [ ] Apple Developer team configured in Xcode.
- [ ] App ID `club.prism.mobile` registered.
- [ ] Distribution certificate + provisioning profile for App Store
      + TestFlight.
- [ ] `ExportOptions.plist` for `flutter build ipa` (gitignored).

---

## 5. API environment

- [ ] `--dart-define=API_BASE_URL=...` set at build time per
      release channel:
      - Internal test / TestFlight: staging API
        (`https://api.staging.<your-domain>/v1`)
      - Production: production API
        (`https://api.club.prism.app/v1` — final URL TBD)
- [ ] `apiBaseUrl` resolver verified in
      [`apps/mobile/lib/core/config.dart`](../apps/mobile/lib/core/config.dart).
      Override always wins (covered by 11 unit tests in
      `apps/mobile/test/config_test.dart`).
- [ ] Production API has TLS termination at the LB / proxy; the
      Flutter client never speaks HTTP to production.
- [ ] iOS: if any HTTP traffic is needed (staging without TLS), set
      `NSAppTransportSecurity` exceptions in `Info.plist` —
      reviewed and removed before production submission.

---

## 6. Privacy policy / data collection

Required by both Play (Data Safety) and App Store (App Privacy).
Engineering inventory and draft form answers live in
[PRIVACY_DATA_INVENTORY.md](PRIVACY_DATA_INVENTORY.md) (DRAFT — for
legal + product review, not a published policy).

- [ ] Privacy policy URL drafted and hosted on a public page (e.g.
      `https://prism.app/privacy/club`).
- [ ] What we collect (matches
      [ANALYTICS.md](ANALYTICS.md) §2 + auth surfaces):
  - **Account info**: user id (UUID), nickname, role(s). Stored
    server-side; the JWT is the only client-side carrier.
  - **User-generated content**: post bodies, reply bodies,
    knowledge contributions, recruitment fields. Stored
    server-side.
  - **Media**: image uploads (jpg/png/webp/gif, ≤ 5 MB). Stored
    server-side under `MEDIA_STORAGE_MODE`.
  - **First-party server-side events**: 11 event types from
    [ANALYTICS.md](ANALYTICS.md) §2. Payloads are scrubbed of body
    text, email, tokens. No third-party tracker.
- [ ] What we do NOT collect:
  - IP address / device id / advertising id (we have neither in
    code nor in the analytics taxonomy).
  - Location.
  - Contacts / calendar / health data.
- [ ] Data Safety form (Play) filled in to match. The "Data shared
      with third parties" answer is **No**.
- [ ] App Privacy form (App Store Connect) filled in to match.
      Tracking = "Not used to track".

---

## 7. Permissions

### Android (`AndroidManifest.xml`)

Current state (audited in `chore(mobile): audit android permissions`):

| Permission | Status | Why |
|---|---|---|
| `INTERNET` | ✅ Declared in `main/AndroidManifest.xml` | Every API call (Dio → REST, media upload, `/v1/auth/login`). The Flutter scaffold's default — declaring it only in debug/profile overlays — would mean the release APK has no network access. Fixed explicitly. |
| `<queries>` for `https` + `http` `VIEW` intents | ✅ Declared | `url_launcher` needs package-visibility queries to discover a browser activity on Android 11+ (API 30+). Used by `ReferenceTile` to open external Reference URLs. |
| `<queries>` for `PROCESS_TEXT` `text/plain` | ✅ Declared | Flutter engine's text-processing plugin (default scaffold). |
| `READ_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES` | ❌ Not declared, by design | `file_picker` 8.x uses the Storage Access Framework — no permission needed. |
| `CAMERA` | ❌ Not declared, by design | Camera capture not implemented. Add only if a future feature needs it. |
| `POST_NOTIFICATIONS` | ❌ Not declared, by design | In-app notifications only; push is deferred (audit §7 / NEXT_BACKLOG §2). Declare when push lands. |
| `WAKE_LOCK` / `RECEIVE_BOOT_COMPLETED` | ❌ Not declared, by design | Would be added by `firebase_messaging` once push lands. |
| `BLUETOOTH*` / `LOCATION*` / `RECORD_AUDIO` | ❌ Not declared, by design | None of these are used. |

Verification: `grep -E "uses-permission" apps/mobile/build/app/intermediates/packaged_manifests/release/.../AndroidManifest.xml`
after the release dry-run build (§12) — the only entries should be
`INTERNET` and the auto-merged
`<package>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` that androidx
runtime broadcasts inject.

- [x] No surprise permissions auto-injected by plugins (verified via
      merged manifest from the debug build).
- [x] `INTERNET` declared in main manifest.
- [x] `url_launcher` Android-11+ queries declared.
- [ ] Re-verify with the release-variant merged manifest before the
      first Play upload (release manifest may differ from debug due
      to other overlays).

### iOS (`Info.plist`)

- [ ] `NSPhotoLibraryUsageDescription` — explains why the app needs
      photo library access for the post image picker. Sample copy:
      "PRISM Club uses your photo library to attach images to your
      posts."
- [ ] No `NSCameraUsageDescription` (camera not used).
- [ ] No `NSLocationWhenInUseUsageDescription` (location not used).

---

## 8. Media upload

- [ ] Image picker (`file_picker`) tested on a physical Android
      device and an iOS device.
- [ ] Server-side 5 MB cap exercised (oversize → 400 + error toast).
- [ ] MIME allowlist exercised (`image/jpeg`, `image/png`,
      `image/webp`, `image/gif`).
- [ ] If `MEDIA_STORAGE_MODE=s3` in the target environment: the
      returned `url` is publicly fetchable, image renders.
- [ ] Camera capture explicitly NOT shipped in Beta (would need
      `image_picker` + `NSCameraUsageDescription` + Android `CAMERA`
      permission — defer).

---

## 9. Auth / session

- [ ] Login picker shows the seeded persona list **only in dev / test
      builds**. Production builds replace it with the real
      `/v1/auth/login` form once that lands
      ([NEXT_BACKLOG.md](NEXT_BACKLOG.md) §1).
- [ ] `flutter_secure_storage`-backed `SessionStorage` confirmed on
      the device:
  - Login → app force-close → app reopen → still logged in.
  - Sign out → app reopen → login picker shown.
- [ ] JWT expiry (7 days, HS256) — when the API returns 401 the app
      drops the token and shows the login picker. No silent retry
      loop.
- [ ] No JWT logged to console / Sentry / crash reporter (current
      code has no such loggers — keep it that way).

---

## 10. Push notifications — decision

**Decision for first Beta:** **defer**. Reasons:

- Server-side `INotificationDeliverer` boundary exists (M17) but
  `push` mode is a stub.
- No Firebase project, no APNs cert, no `firebase_messaging`
  dependency in `pubspec.yaml`.
- In-app notifications fully work — users see them on next app
  open.
- Adding push is gated on the server-side provider work
  ([NEXT_BACKLOG.md](NEXT_BACKLOG.md) §2).

When push is required (post-Beta): file the Firebase project setup,
add `firebase_messaging`, wire `<service>` in `AndroidManifest.xml`,
add `UIBackgroundModes = remote-notification` in iOS `Info.plist`,
implement `PushDelivery` on the API.

- [ ] **CONFIRM** push is deferred for this release in the release
      ticket; mark the post-Beta follow-up.

---

## 11. QA

Capture each physical-device pass in
[MOBILE_DEVICE_QA_LOG.md](MOBILE_DEVICE_QA_LOG.md) — one filled log per
device × build combination is what the §11 box below signs off on.

Use [ANDROID_DEVICE_RUNBOOK.md](ANDROID_DEVICE_RUNBOOK.md) to get
emulator / physical device up and pointed at the right API, then run
[MOBILE_QA_SCRIPT.md](MOBILE_QA_SCRIPT.md) for fast iteration against
the local API, then run [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md) on a
real device against the staging API before submitting an internal
test build.

- [ ] Android emulator pass — every section §1–§7.
- [ ] At least one **physical Android device** pass (so we exercise
      real SecureSessionStorage / file_picker / TLS).
- [ ] iOS Simulator pass (after iOS scaffold lands).
- [ ] At least one **physical iOS device** pass.
- [ ] Korean text input + RTL of any future locales sanity-checked
      (PRISM Club is currently Korean-only).
- [ ] Image upload + thumbnail render on slow Wi-Fi.
- [ ] Sign-out + sign-back-in restores feed state from server (no
      stale local cache).

---

## 12. Build commands

Final release builds — every command should be reproducible from a
clean clone.

### Android (Play Store AAB)

```bash
cd apps/mobile
flutter pub get
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.club.prism.app/v1
# Output: build/app/outputs/bundle/release/app-release.aab
```

The Play upload step expects an AAB. Use Play App Signing so the
upload key is the only one we manage. Today the AAB builds but is
debug-signed and Play-rejected — see
[ANDROID_RELEASE_DRY_RUN.md](ANDROID_RELEASE_DRY_RUN.md) for the
exact unblockers.

### Android (APK for ad-hoc sideload)

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.club.prism.app/v1
# Output: build/app/outputs/flutter-apk/app-release.apk
```

Useful for QA distribution outside Play tracks. Not the Store
artifact.

### iOS (App Store Connect IPA)

Requires macOS + Xcode + distribution provisioning profile.

```bash
cd apps/mobile
flutter pub get
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://api.club.prism.app/v1
# Output: build/ios/ipa/Runner.ipa
```

Upload via `xcrun altool` or Transporter app.

### Per-environment override matrix

| Build target | `--dart-define=API_BASE_URL=` |
|---|---|
| Internal alpha (devs only) | local LAN IP for the dev box |
| TestFlight / Closed track | `https://api.staging.<your-domain>/v1` |
| Open Beta / Play public test | `https://api.staging.<your-domain>/v1` (until production is ready) → production URL once cut over |
| Production | `https://api.club.prism.app/v1` (final URL TBD) |

---

## 13. Submission gates

Track each item against a real release ticket — none of these are
engineering-blocked at this point. The Play-specific subset has its
own walkthrough at
[PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md) — start there
for the first AAB upload.

- [ ] Google Play developer account active.
- [ ] Apple Developer Program membership active.
- [ ] App created in Play Console (`Internal testing` track first).
- [ ] App created in App Store Connect (`TestFlight` first).
- [ ] Store listing copy: short description, full description,
      what's new (1.0 release notes), keywords (iOS).
- [ ] Screenshots: required sizes (phone + 7-inch tablet for Play;
      iPhone 6.7" + 5.5" for App Store). Captured from the installed
      Internal build — see
      [PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md) §6.5.
- [x] Feature graphic (Play) — 1024 × 500 — committed at
      `apps/mobile/assets/branding/play_feature_graphic.png`. Operator
      uploads to Play Console (no automated push).
- [ ] App preview video (iOS, optional).
- [ ] Privacy policy URL (per §6).
- [ ] Content rating (Play IARC questionnaire + App Store age
      rating).
- [ ] Target audience + content guidelines (Play).
- [ ] Pricing & distribution.
- [ ] Promotion review (App Store: human review can take days).

---

## 14. Sign-off

When every box above is checked, file the release ticket with this
filled block:

```
PRISM Club — Mobile Release Sign-off
====================================
Release name           : <e.g. 0.1.0 Beta 1>
Release channel        : <Internal | Closed | Open | Production>
Date / approver        : <YYYY-MM-DD / name>

Android
  versionName / code   : <0.1.0 / 1>
  applicationId        : club.prism.mobile
  Signing              : <upload key alias>
  Artifact             : <SHA-256 of the AAB>
  Play track           : <Internal | Closed | Open | Production>

iOS
  CFBundleShortVersion : <0.1.0>
  CFBundleVersion      : <1>
  Bundle id            : club.prism.mobile
  Signing              : <distribution cert thumbprint>
  Artifact             : <SHA-256 of the IPA>
  TestFlight / Store   : <track name>

Configuration
  API_BASE_URL         : <staging | production URL>
  Session storage      : flutter_secure_storage (mobile)
  Push                 : deferred

QA
  Android (physical)   : <PASS / FAIL — device model>
  iOS (physical)       : <PASS / FAIL — device model>
  BETA_QA_SCRIPT pass  : <PASS / FAIL — sections>

Privacy / paperwork
  Privacy policy URL   : <link>
  Data Safety form     : <Play status>
  App Privacy form     : <App Store status>
  Screenshots          : <attached / link>

Verdict                : <SUBMIT / HOLD>
Outstanding items      : <list, or "none">

Signed                  : <name + date>
```

Mark **SUBMIT** only when every section above resolves green and the
release ticket has the matching attachments. Move to **HOLD** → fix →
re-check.
