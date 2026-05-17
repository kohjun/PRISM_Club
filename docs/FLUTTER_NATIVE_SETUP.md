# PRISM Club — Flutter Native Setup

Day-to-day reference for running PRISM Club on Android (and iOS, once
the macOS scaffold lands). The official release target is the native
app — web is local QA only ([LOCAL_BROWSER_QA.md](LOCAL_BROWSER_QA.md))
and staging exists for cut-over rehearsal
([STAGING_BRINGUP_CHECKLIST.md](STAGING_BRINGUP_CHECKLIST.md)).

Pairs with:

- [FLUTTER_APP_RELEASE_AUDIT.md](FLUTTER_APP_RELEASE_AUDIT.md) —
  inventory of remaining gaps
- [LOCAL_BROWSER_QA.md](LOCAL_BROWSER_QA.md) — web target / local QA
- [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) — store
  submission checklist (in progress alongside this doc)

---

## 1. Current platform state

| Platform | Folder | Buildable? | Notes |
|---|---|---|---|
| Web (Chrome / Edge) | `apps/mobile/web/` | ✅ Yes | `flutter build web --no-tree-shake-icons` |
| Android | `apps/mobile/android/` | ✅ Yes (debug); release signing is a TODO | `applicationId=club.prism.mobile`; default icon + splash |
| iOS | _missing_ | ❌ Not on Windows | Folder must be created on macOS — see §3 |

`flutter doctor` from a Windows host (current dev workstation):

```
[√] Flutter 3.41.7
[√] Android toolchain (SDK 36.1.0)
[√] Chrome (web)
[!] Visual Studio Build Tools — missing C++ components (Windows
    desktop target not in scope)
```

---

## 2. Android — run + build

### 2.1 Prerequisites

- Android SDK (Platform Tools, Build Tools, an emulator image).
  `flutter doctor` walks you through any missing pieces.
- Java 17 (the project's `compileOptions` pin to `VERSION_17`).
- Either a started emulator (`flutter emulators --launch <name>`) or
  a device with USB debugging enabled.

### 2.2 Run on an emulator

```bash
cd apps/mobile
flutter pub get
flutter emulators              # list configured AVDs
flutter emulators --launch <emulator-id>   # start one (or use Android Studio)
flutter devices                # confirm the emulator appears
flutter run -d <device-id>     # hot-reloads on save
```

The default `apiBaseUrl` on an Android emulator resolves to
`http://10.0.2.2:3000/v1` — that's the emulator's loopback to the host
machine. No override needed when your local API is running on
`localhost:3000`.

### 2.3 Run on a physical Android device

USB debugging on, device shows up in `flutter devices`. The default
`apiBaseUrl` is `http://localhost:3000/v1` on the device, which **does
NOT reach your laptop** — you must override:

```bash
# Find your laptop's LAN IP first (e.g. 192.168.1.42).
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=http://192.168.1.42:3000/v1
```

Make sure the API binds to all interfaces (`API_PORT=3000` is fine —
NestJS listens on `0.0.0.0` by default) and your firewall allows the
inbound connection on 3000.

If you intend to point the device at staging:

```bash
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=https://api.staging.<your-domain>/v1
```

### 2.4 Build a debug APK (for ad-hoc install)

```bash
cd apps/mobile
flutter build apk --debug
# Output: apps/mobile/build/app/outputs/flutter-apk/app-debug.apk
```

`adb install -r build/app/outputs/flutter-apk/app-debug.apk` sideloads
it.

### 2.5 Build a release APK (debug-signed for now)

```bash
flutter build apk --release
```

**Will succeed**, but the artifact is signed with the Flutter debug
keystore — fine for internal smoke testing, **not** acceptable for
Play Store. See
[FLUTTER_APP_RELEASE_AUDIT.md](FLUTTER_APP_RELEASE_AUDIT.md) §2.3 for
the release-signing gap.

### 2.6 Build a Play Store bundle (blocked)

```bash
flutter build appbundle --release
# Output: apps/mobile/build/app/outputs/bundle/release/app-release.aab
```

The bundle is produced but rejected by Play because of debug
signing — same blocker as §2.5. Resolve before first upload.

### 2.7 Known local setup gaps (Windows)

- Visual Studio C++ Build Tools components are missing
  (`flutter doctor` warning). This only blocks the Windows desktop
  target, which we do NOT ship. Safe to ignore.
- The Android NDK auto-installs the first time you build. Expect a
  one-time ~3 GB download.

---

## 3. iOS — run + build (macOS follow-up)

`apps/mobile/ios/` **does not exist in the repo.** Creating it from a
Windows host would commit untested scaffolding — instead, follow
these steps on a macOS workstation:

```bash
# Prereqs (macOS, one-time):
xcode-select --install
sudo gem install cocoapods

# From the repo root:
cd apps/mobile
flutter pub get
flutter create --platforms=ios .
# This writes apps/mobile/ios/Runner.xcodeproj and friends.

# Set the bundle identifier to match Android:
open ios/Runner.xcworkspace
# In Xcode → Runner target → General → Bundle Identifier →
# club.prism.mobile

# Commit the new ios/ folder.
git add ios/
git commit -m "chore: add ios scaffold"
```

After the scaffold exists, the usual commands work:

```bash
# Simulator:
open -a Simulator                               # boot iOS Simulator
flutter run -d <simulator-id>

# Physical device (requires team signing in Xcode):
flutter run -d <device-id>

# Release build:
flutter build ios --release            # archives .app
flutter build ipa --release            # archives + exports .ipa
```

For physical-device + staging:

```bash
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=https://api.staging.<your-domain>/v1
```

(iOS simulator follows the same `localhost` default as Chrome — no
override needed when the local API is running on `localhost:3000`.)

---

## 4. API base URL on each surface

| Surface | Effective default | Override needed? |
|---|---|---|
| Chrome / Edge web | `http://localhost:3000/v1` | No, while developing locally |
| Android emulator | `http://10.0.2.2:3000/v1` | No |
| iOS Simulator | `http://localhost:3000/v1` | No |
| Physical Android | `http://localhost:3000/v1` ← broken | **Yes** — `--dart-define=API_BASE_URL=http://<lan-ip>:3000/v1` |
| Physical iOS | `http://localhost:3000/v1` ← broken | **Yes** — same |
| Staging (any device) | n/a | **Yes** — `--dart-define=API_BASE_URL=https://api.staging.<your-domain>/v1` |
| Production (any device) | n/a | **Yes** — `--dart-define=API_BASE_URL=https://api.club.prism.app/v1` (final URL TBD) |

The resolver lives at `apps/mobile/lib/core/config.dart` —
`String.fromEnvironment('API_BASE_URL')` always wins when set. The
override is **trimmed** and any **trailing slash** is stripped so
`https://api.example.com/v1/` and `https://api.example.com/v1` are
treated identically. The pure form (`resolveApiBaseUrl(...)`) is
exhaustively tested in `apps/mobile/test/config_test.dart` (11
cases).

Concrete examples:

```bash
# Chrome (local dev) — no override needed:
flutter run -d chrome

# Chrome against a remote dev API:
flutter run -d chrome \
  --dart-define=API_BASE_URL=https://api.dev.<your-domain>/v1

# Android emulator (local API) — no override needed:
flutter run -d <emu-id>

# Physical Android device against your laptop's API:
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=http://192.168.1.42:3000/v1

# Physical Android device against staging:
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=https://api.staging.<your-domain>/v1

# Production app store build:
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.club.prism.app/v1
```

---

## 5. Test surface (same on every platform)

```bash
cd apps/mobile
flutter analyze           # info-only items expected; no errors / warnings
flutter test              # 53+ widget tests, all green
flutter build web --no-tree-shake-icons   # full web compile
# Optional Android pre-flight (slow first time — downloads NDK):
flutter build apk --debug
```

Tests are platform-agnostic by design — they exercise the Riverpod
data layer + widget rendering, not platform plugins. Adding more
platform-coupled tests (e.g. for `flutter_secure_storage`) should
prefer mock-driven coverage over device-coupled coverage.

---

## 6. Troubleshooting

### Gradle / Java mismatch on Android build

The project pins Java 17. Verify:

```bash
java -version       # 17.x
gradle --version    # confirms JAVA_HOME points at the same 17
```

If your `JAVA_HOME` points at 11 or 8, Gradle will fail with a
cryptic `Unsupported class file major version`. Switch JAVA_HOME and
re-run.

### "Could not find device"

`flutter devices` is the source of truth. If your emulator is up but
absent from the list, it failed to boot — open Android Studio's AVD
Manager and start it from there to get the diagnostic. Physical
devices need USB debugging on AND the laptop authorized in the
device's "USB debugging" prompt.

### "INSTALL_FAILED_USER_RESTRICTED" sideloading on physical device

Some OEM ROMs (Xiaomi, OPPO) block ADB-installed APKs until you
toggle "Install via USB" in developer settings.

### Web works but Android emulator can't reach the API

The emulator default is `10.0.2.2` (host's loopback as seen from the
emulator). If you've overridden `apiBaseUrl` to `localhost:3000`
manually, the emulator will try to reach the emulator's own loopback,
which has nothing on port 3000.

### iOS folder reappears as untracked on every `flutter run`

Flutter does NOT auto-generate `ios/` on Windows. If you ever see
that, something in your toolchain is doing it — investigate before
committing.

---

## 7. Quick reference card

```bash
# Bring up local API + DB first (see LOCAL_BROWSER_QA.md §2):
docker compose up -d postgres
npx prisma migrate dev && npm run db:seed
npm run api:dev

# In another shell — Android emulator:
cd apps/mobile
flutter pub get
flutter run -d <android-emulator-id>           # no --dart-define needed

# Physical Android device against laptop API:
flutter run -d <android-device-id> \
  --dart-define=API_BASE_URL=http://<lan-ip>:3000/v1

# Web (alternate local QA target):
flutter run -d chrome

# Builds:
flutter build apk --debug                       # ad-hoc sideload
flutter build apk --release                     # internal smoke (debug-signed)
flutter build appbundle --release               # Play upload (blocked on signing)

# Tests:
flutter analyze && flutter test
flutter build web --no-tree-shake-icons
```
