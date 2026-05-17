# PRISM Club — Flutter App Release Readiness Audit

The official PRISM Club release target is the **native Flutter app**
(Android + iOS). Browser testing is local QA only — see
[LOCAL_BROWSER_QA.md](LOCAL_BROWSER_QA.md). This document inventories
what currently exists, what is missing, and what order to address the
gaps in. **No code is changed by this audit.**

> Snapshot taken against commit `10d7ab6 docs: add local browser qa guide`.
> `flutter analyze` reports 6 info-only items; `flutter test` is 53/53
> green; `flutter build web --no-tree-shake-icons` succeeds.

Pairs with:

- [BETA_READINESS.md](BETA_READINESS.md) — feature map M1–M20
- [LOCAL_BROWSER_QA.md](LOCAL_BROWSER_QA.md) — local QA mode
- [BETA_LAUNCH_RUNBOOK.md](BETA_LAUNCH_RUNBOOK.md) — server-side cut-over
- [NEXT_BACKLOG.md](NEXT_BACKLOG.md) — deferred items

---

## 1. Current Flutter target support

| Target | Folder | Status | Notes |
|---|---|---|---|
| **Web** (Chrome) | `apps/mobile/web/` | ✅ Working | Default for local QA. `flutter build web --no-tree-shake-icons` succeeds. |
| **Android** | `apps/mobile/android/` | ⚠️ Skeleton only | Flutter scaffold present; applicationId set; **default icon, default splash, debug signing**. Manifest has no permissions, no deep-link intent-filters, no FileProvider. |
| **iOS** | `apps/mobile/ios/` | ❌ **MISSING** | Folder does not exist. Needs `flutter create --platforms=ios .` from a macOS host (Windows cannot drive iOS builds). |
| **Windows / macOS / Linux desktop** | n/a | Not in scope | We don't ship desktop builds for Beta. |

`flutter doctor` from the development workstation
(commit `10d7ab6`, Windows 11):

```
[√] Flutter (Channel stable, 3.41.7)
[√] Android toolchain (Android SDK 36.1.0)
[√] Chrome (web)
[√] Connected device (3 available)
[!] Visual Studio Build Tools — missing C++ components (not needed for Android / web)
```

---

## 2. Android readiness

### 2.1 Project metadata

| Field | Current value | Status | Required for release |
|---|---|---|---|
| `applicationId` | `club.prism.mobile` | ✅ Set | yes — final value before first Play Store upload |
| `namespace` | `club.prism.mobile` | ✅ Set | yes |
| `compileSdk` | `flutter.compileSdkVersion` (currently 34+) | ✅ Inherited | yes |
| `minSdk` | `flutter.minSdkVersion` (currently 21) | ✅ Inherited | yes |
| `targetSdk` | `flutter.targetSdkVersion` | ⚠️ Should pin to current Play target (34 today) | yes — required by Play Console policy |
| `versionCode` / `versionName` | `flutter.versionCode` / `flutter.versionName` (read from pubspec `version: 0.1.0+1`) | ✅ Wired | yes — bump per release |
| Java target | 17 | ✅ Set | yes |
| Kotlin target | 17 | ✅ Set | yes |

### 2.2 Manifest (`android/app/src/main/AndroidManifest.xml`)

| Item | Status | Required for release |
|---|---|---|
| `MAIN` / `LAUNCHER` intent-filter | ✅ | yes |
| `<application android:label>` | ⚠️ Currently `"mobile"` — should be `"PRISM Club"` | yes (Play listing label is separate; this is the launcher label) |
| `<application android:icon>` | ⚠️ Default Flutter icon (`@mipmap/ic_launcher`) | yes — needs branded icon |
| `INTERNET` permission | ✅ Auto-added in debug manifest by Flutter | yes |
| Adaptive icon | ❌ Not configured | recommended — Play prefers adaptive icons since API 26 |
| Notification channels | ❌ Not configured | only when push lands (NEXT_BACKLOG §2) |
| `<queries>` for `PROCESS_TEXT` | ✅ Present (Flutter default) | yes |
| Deep-link intent-filters | ❌ None beyond MAIN/LAUNCHER | required if we ship `https://club.prism.app/...` or `prism://...` deep links |
| `FileProvider` for image picker | ❌ Not configured | required if/when we use camera capture; `file_picker` plugin handles gallery select without it today |

### 2.3 Release signing

Currently:

```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        // Signing with the debug keys for now, so `flutter run --release` works.
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

**Blocks the first Play Store upload.** A debug-signed AAB is rejected.
Need:

- An upload key (Play recommends App Signing by Google Play, so the
  upload key is the only one we manage).
- `android/key.properties` listing the keystore path + aliases +
  passwords (gitignored — `**/android/key.properties` is in
  `.gitignore`).
- `signingConfigs.release` reading from that file.
- A keystore file stored in the team password vault (NOT in git).

### 2.4 Build commands (audit, not run)

| Command | What it produces |
|---|---|
| `flutter build apk --release` | A single fat APK; useful for ad-hoc distribution. NOT for Play Store. |
| `flutter build appbundle --release` | The `.aab` Play Store upload artifact. Blocked by §2.3 release signing. |

---

## 3. iOS readiness

### 3.1 Project metadata

**No `apps/mobile/ios/` folder exists in the repo.** Everything below
is gap analysis, not status.

| Item | Status | Required for release |
|---|---|---|
| `ios/` scaffold | ❌ Missing | yes — needs `flutter create --platforms=ios .` on macOS |
| `CFBundleIdentifier` | n/a | `club.prism.mobile` (matches Android applicationId) |
| `Info.plist` | n/a | needs at minimum: `CFBundleDisplayName=PRISM Club`, `NSPhotoLibraryUsageDescription` (image picker), `NSAppTransportSecurity` allowance for staging if HTTP |
| Bundle version / build number | n/a | wire to pubspec `version` like Android |
| Code signing | n/a | needs Apple Developer team + provisioning profile |
| App icon set | n/a | needs `AppIcon.appiconset` with all required sizes |
| Launch storyboard | n/a | Flutter default is fine for Beta |

### 3.2 Toolchain reality

iOS builds **cannot be run from the current Windows workstation**.
Recommended sequence for the macOS engineer who will pick this up:

```bash
# From the repo root on macOS:
cd apps/mobile
flutter pub get
flutter create --platforms=ios .
# This generates apps/mobile/ios/ with the standard scaffold.

# Set the bundle identifier:
# Open ios/Runner.xcodeproj in Xcode → Runner target →
# General → Bundle Identifier → "club.prism.mobile"

flutter run -d <iphone-simulator>
flutter build ios --release       # produces .app for archiving
flutter build ipa --release       # produces .ipa for App Store Connect
```

Re-run `flutter doctor` on the macOS host first — it will list
exactly which Xcode / CocoaPods / Pods state is missing.

---

## 4. API base URL strategy

`apps/mobile/lib/core/config.dart` selects the URL at runtime:

```dart
String get apiBaseUrl {
  const override = String.fromEnvironment('API_BASE_URL');
  if (override.isNotEmpty) return override;
  if (kIsWeb) return 'http://localhost:3000/v1';
  if (Platform.isAndroid) return 'http://10.0.2.2:3000/v1';
  return 'http://localhost:3000/v1';
}
```

| Target | Effective default | Override |
|---|---|---|
| Chrome (web) | `http://localhost:3000/v1` | `--dart-define=API_BASE_URL=...` |
| Android emulator | `http://10.0.2.2:3000/v1` (emulator → host) | same |
| iOS simulator | `http://localhost:3000/v1` | same |
| Physical Android device | `http://localhost:3000/v1` (**broken** — won't reach the laptop) | **must** use `--dart-define` |
| Physical iOS device | same — broken default | **must** use `--dart-define` |
| Production app | n/a — must be set at build time | `--dart-define=API_BASE_URL=https://api.club.prism.app/v1` |

**Gap.** Physical devices fall through to the localhost default and
silently fail to reach the API. Tracked for the next pass — see the
recommended PR sequence in §11.

---

## 5. Secure token storage status

Hardened in the `feat(mobile): harden session storage` commit. Current
behavior:

| Component | Today | Surface |
|---|---|---|
| `SessionStorage` abstraction (`lib/core/session_storage.dart`) | Two production implementations behind a Riverpod provider | Tests override with an in-memory fake |
| `SharedPrefsSessionStorage` | `shared_preferences` (browser `localStorage` on web) | Selected on web — browsers have no real keychain equivalent. Same behavior as M13. |
| `SecureSessionStorage` | `flutter_secure_storage`: Android Keystore-backed `EncryptedSharedPreferences` + iOS Keychain (`first_unlock_this_device`) | Selected on Android + iOS. JWT is never written in plaintext on a native install. |
| `CurrentUserNotifier` (`lib/core/current_user.dart`) | Reads / writes through `SessionStorage` only — does not know which backend is in use | Logout + session restore flows unchanged from M13. |

**Migration note for existing installs.** Native installs that
previously stored the JWT in `SharedPreferences` will see an empty
secure-storage read on first launch after upgrade and bounce back to
the login picker. The user re-authenticates once. Web installs are
unaffected (still `SharedPreferences`).

---

## 6. Media / file picker status

| Surface | Today | Gap |
|---|---|---|
| Image picker (post composer) | `file_picker` plugin selects images from gallery; size cap enforced server-side (5 MB) | ✅ Works on web + Android. iOS needs `NSPhotoLibraryUsageDescription` in `Info.plist`. |
| Camera capture | Not implemented | Not required for Beta. Adding camera needs `image_picker` (more native), Android `CAMERA` permission, iOS `NSCameraUsageDescription`. |
| File preview | Inline in composer via `Image.network` (after upload) | ✅ Works |
| Avatar upload | Not implemented (NEXT_BACKLOG §6) | n/a for Beta |
| Image antivirus / resize / CDN | Not implemented (NEXT_BACKLOG §4) | Server-side concern, not Flutter |

---

## 7. Push notification readiness

**Zero push integration.** Notifications are in-app only:

- `NotificationScreen` at `/me/notifications` reads
  `GET /v1/me/notifications` and shows the unread badge.
- The API's notification fan-out goes through `INotificationDeliverer`
  with `noop` / `email` / `push` modes (M17) — only `noop` is wired.
- No FCM project, no APNs cert, no `firebase_messaging` dependency,
  no `<service>` registration in `AndroidManifest.xml`, no
  `UIBackgroundModes` in `Info.plist`.

Push is explicitly deferred — see [NEXT_BACKLOG.md](NEXT_BACKLOG.md)
§2. Beta will ship without push; users see notifications only when
they open the app.

---

## 8. App icon / splash status

| Asset | Status | Gap |
|---|---|---|
| Android launcher icon (`mipmap-*/ic_launcher.png`) | ⚠️ Default Flutter "F" icon present in all densities | Replace with PRISM Club brand mark before Play upload. Recommend `flutter_launcher_icons` package for one-config-fits-all generation. |
| Android adaptive icon | ❌ Not configured | Recommended; needs `ic_launcher_foreground.xml` + `ic_launcher_background.xml` in `mipmap-anydpi-v26/`. |
| Android splash background | ⚠️ Default white (`launch_background.xml`) | Replace with brand background. `flutter_native_splash` can generate. |
| iOS app icon set | ❌ N/A (ios/ folder missing) | Generate alongside §3 scaffold. |
| iOS launch storyboard | ❌ N/A | Default is acceptable for Beta. |

---

## 9. Deep link status

`go_router` handles internal navigation but has **no platform deep
link wiring**:

- `AndroidManifest.xml` has no `<intent-filter>` declaring
  `https://club.prism.app/...` (App Links) or `prism://...`
  (custom scheme).
- No `apple-app-site-association` reference (iOS Universal Links —
  served from the production web host).
- No `app_links` or `uni_links` dependency.

For Beta this means:

- Sharing a post link copies the URL but tapping it on a phone opens
  the browser, not the app.
- Email / push deep links won't open into specific screens.

Tracked as a post-Beta item. Add to NEXT_BACKLOG when the Beta release
window is scheduled.

---

## 10. Store submission gaps

| Item | Android (Play Console) | iOS (App Store Connect) |
|---|---|---|
| Developer account | ❌ Required | ❌ Required ($99/yr) |
| App created in console | ❌ Required | ❌ Required |
| Privacy policy URL | ❌ Required (Play form + Data Safety) | ❌ Required (App Privacy form) |
| Data Safety / App Privacy declarations | ❌ Required — must list JWT, device id (if used), media uploads, analytics_events | same |
| Content rating | ❌ Required (IARC questionnaire) | ❌ Required (age rating) |
| Target audience + age | ❌ Required | ❌ Required |
| Store listing copy + screenshots | ❌ Required | ❌ Required |
| Pricing & distribution | ❌ Required | ❌ Required |
| Test track configuration | ❌ Required (Internal → Closed → Open beta) | ❌ Required (TestFlight) |
| Signed upload artifact | ❌ Blocked by §2.3 | ❌ Blocked by §3 |

Beta release requires all of the above on **at least one** store; the
team can soft-launch on Android only first if Apple Developer
onboarding lags.

---

## 11. Recommended PR sequence

These are the discrete chunks that should land before the first Beta
build is uploaded to a store. Each one is a separate PR so it can be
reviewed in isolation.

1. **Add `apps/mobile/ios/` scaffold** (macOS engineer) —
   `flutter create --platforms=ios .` + set `CFBundleIdentifier` +
   commit the generated tree.
2. **Pin Android targetSdk explicitly** in
   `android/app/build.gradle.kts` and bump to the current Play target.
3. **Branded app icon + splash** (both platforms) via
   `flutter_launcher_icons` + `flutter_native_splash`. Source SVG /
   PNG from the design owner.
4. **Set up release signing** (Android upload key + iOS provisioning
   profile) and the corresponding gitignored `key.properties` /
   `ExportOptions.plist`.
5. **Physical-device API URL handling** — make `apiBaseUrl` log the
   resolved URL on boot in debug mode; document the
   `--dart-define=API_BASE_URL=...` pattern for physical devices
   (cross-link [LOCAL_BROWSER_QA.md](LOCAL_BROWSER_QA.md)).
6. **Secure token storage** — ✅ DONE in `feat(mobile): harden
   session storage`. `SessionStorage` abstraction with
   `flutter_secure_storage` on native and `SharedPreferences` on web.
   8 tests cover the load / save / clear contract plus
   `CurrentUserNotifier` login → restart → restore → signOut.
7. **Update `<application android:label>`** to "PRISM Club" + verify
   `pubspec.yaml` `description` is brand-final.
8. **Privacy policy + Data Safety draft** — owned by legal / product;
   reference the analytics taxonomy from
   [ANALYTICS.md](ANALYTICS.md) §2 for the data-collection section.
9. **First Play Console internal test upload** — debug-style smoke on
   a real device against staging (`--dart-define=API_BASE_URL=
   https://api.staging.club.prism.app/v1`).
10. **Deep linking (post-Beta)** — pick App Links vs. custom scheme;
    add `<intent-filter>` + `apple-app-site-association`; wire
    `go_router` to handle the incoming URLs.
11. **Push notifications (post-Beta)** — Firebase project, FCM/APNs
    cert, `firebase_messaging` dependency, server-side
    `PushDelivery` provider implementation.

Items 1–8 are blocking for the first store upload. Items 9–11 are
sequenced for after Beta is in users' hands.

---

## 12. Summary

Beta-release-blockers, ranked:

| # | Blocker | Estimated effort |
|---|---|---|
| 1 | iOS scaffold missing (`ios/` folder doesn't exist) | small — requires macOS access |
| 2 | Release signing config (Android upload key + iOS provisioning) | small — one PR per platform |
| 3 | App icon + splash (both platforms) | small — design-blocked, not engineering-blocked |
| 4 | Physical-device API URL falls through to localhost | trivial — already supports `--dart-define` |
| 5 | JWT stored in `SharedPreferences` plaintext on native | ✅ DONE — `feat(mobile): harden session storage` |
| 6 | Privacy policy + Data Safety / App Privacy declarations | depends on legal turnaround |
| 7 | Store listing copy + screenshots | depends on marketing turnaround |
| 8 | Developer account onboarding (Google + Apple) | clock-blocked, not engineering-blocked |

None of the above require product code changes beyond §5; the rest
are configuration + assets + store paperwork. With macOS access and
release-signing keys, a Beta-shaped build is reachable in **one to
two PR cycles**.
