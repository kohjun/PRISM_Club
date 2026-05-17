# PRISM Club — Android Device Runbook

How a non-developer tester gets PRISM Club running on an Android
emulator or a physical Android device, pointed at the local NestJS
API. Optimized for "I just want to tap through the app" rather than
"I'm here to write code."

> Companion docs for deeper detail:
>
> - [FLUTTER_NATIVE_SETUP.md](FLUTTER_NATIVE_SETUP.md) — developer-
>   level build / debug / troubleshooting commands.
> - [LOCAL_BROWSER_QA.md](LOCAL_BROWSER_QA.md) — the same flows but
>   in Chrome (faster when you don't need a real device).
> - [MOBILE_QA_SCRIPT.md](MOBILE_QA_SCRIPT.md) — the QA checklist you
>   walk THROUGH the app once it's running.
> - [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) — store
>   submission gates.

---

## 1. Prerequisites

A small one-time setup. Once these are in place, everything below is
copy-paste.

### On your laptop

- [ ] **Flutter ≥ 3.41** on PATH (`flutter --version`).
- [ ] **Android SDK + emulator** (Android Studio sets this up the
      easiest). `flutter doctor` walks through any gaps.
- [ ] **Repo cloned** and `npm install` run at the repo root.
- [ ] **Local API stack** has been brought up at least once by
      following [LOCAL_BROWSER_QA.md](LOCAL_BROWSER_QA.md) §2. You
      can verify with:
      ```bash
      docker compose ps postgres
      curl -sS http://localhost:3000/v1/health
      ```

### On the device (physical only)

- [ ] **USB debugging on** — Settings → About phone → tap **Build
      number** 7 times to unlock developer options, then Settings →
      Developer options → **USB debugging**.
- [ ] **USB cable** that supports data transfer (some "charge-only"
      cables look identical and won't show up to `adb`).
- [ ] First USB connection prompts on the device → **Allow USB
      debugging from this computer** (check "always allow").

---

## 2. Emulator setup

Quickest path for testing — no physical device needed.

```bash
cd apps/mobile
flutter pub get

# List configured AVDs
flutter emulators

# Start one (or use Android Studio's AVD Manager GUI)
flutter emulators --launch <emulator-id>

# Confirm the emulator appears
flutter devices
```

If `flutter emulators` is empty, open Android Studio → Tools → Device
Manager → Create Device → pick a phone profile → finish. Then re-run
`flutter emulators`.

---

## 3. Physical device setup

If `flutter devices` doesn't list your phone after you plugged it in:

```bash
adb kill-server
adb start-server
adb devices
```

`adb devices` should list your phone's serial number with the
**device** status. If it says `unauthorized`, look at the phone —
there's a USB-debugging-trust prompt to accept.

---

## 4. Local API networking — which URL?

This is the one part everyone gets wrong on the first try. The right
answer depends on where the app is running.

| App is running on | Reach the laptop API at | Why |
|---|---|---|
| Chrome on the laptop (web) | `http://localhost:3000/v1` | Same machine. |
| Android emulator (on the laptop) | `http://10.0.2.2:3000/v1` | The emulator's loopback (`127.0.0.1`) is the emulator itself. `10.0.2.2` is its alias for the host machine. |
| Physical Android device (same Wi-Fi) | `http://<laptop-LAN-IP>:3000/v1` | The phone needs to reach the laptop over the LAN. |
| iOS Simulator (on a Mac) | `http://localhost:3000/v1` | Like Chrome — same machine. |

The Flutter app's default URL resolver does the right thing for **web
and Android emulator** without any flags. For **physical devices**,
you must pass the laptop's LAN IP via `--dart-define`.

### Find the laptop's LAN IP

```bash
# Windows
ipconfig | findstr IPv4

# macOS / Linux
ifconfig | grep "inet " | grep -v 127.0.0.1
```

Pick the IPv4 address on your active Wi-Fi network — usually
`192.168.x.x` or `10.x.x.x`. Write it down; you'll need it.

### Verify the device can reach the API

Open a browser on the phone and visit
`http://<laptop-LAN-IP>:3000/v1/health` — you should see
`{"ok":true}`. If you don't:

- **Windows firewall** is probably blocking inbound port 3000. Allow
  it: `wf.msc` → Inbound Rules → New Rule → Port → TCP 3000 → Allow.
- **macOS firewall** (if enabled): System Settings → Network →
  Firewall → Allow `node` to accept incoming connections.
- **Phone is on a different network** (e.g. mobile data instead of
  the office Wi-Fi). Reconnect to the same Wi-Fi as the laptop.

---

## 5. `--dart-define=API_BASE_URL=` examples

Concrete commands you can copy. Substitute `<lan-ip>` with the laptop
IP from §4.

### Emulator, local API (most common)

```bash
cd apps/mobile
flutter run -d <emulator-id>
```

No override needed. The emulator default `10.0.2.2:3000/v1` works.

### Emulator, custom port (rare)

```bash
flutter run -d <emulator-id> \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080/v1
```

### Physical device, local API

```bash
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=http://192.168.1.42:3000/v1
```

### Physical device, against staging (skip the local API entirely)

```bash
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=https://api.staging.<your-domain>/v1
```

### What "future production" will look like

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.club.prism.app/v1
```

(Production URL is TBD. The pattern stays the same.)

---

## 6. Install + run

### Run from `flutter run` with hot reload

```bash
cd apps/mobile
flutter pub get          # first run only
flutter run -d <device-or-emulator-id> \
  [--dart-define=API_BASE_URL=http://<lan-ip>:3000/v1]   # only for physical device
```

`flutter run` keeps an interactive shell open:

- `r` — hot reload (re-applies code changes without losing state).
- `R` — hot restart (rebuilds the app from scratch; sometimes needed
  after Riverpod provider changes).
- `q` — quit.

### Install a prebuilt debug APK (no `flutter run` needed)

If a developer has already built a debug APK and handed it to you:

```bash
# Verify the device is connected
adb devices

# Install (the -r flag lets you re-install over an existing app)
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Build path on a developer machine:

```bash
cd apps/mobile && flutter build apk --debug
```

The APK lives at `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`.

> **Note.** A debug APK built without `--dart-define=API_BASE_URL=...`
> bakes the developer's default (emulator → `10.0.2.2:3000/v1`,
> physical → `localhost:3000/v1`). If you're handed a prebuilt APK to
> install on a physical device, ask the developer which API URL was
> baked in. If it doesn't match your network, you'll see a
> "connection refused" error in the app — the developer will need to
> rebuild with the right `--dart-define`.

---

## 7. Logs + troubleshooting

### See app logs

While `flutter run` is open, every log line from the app prints in
that shell. To see logs from an installed APK without `flutter run`:

```bash
adb logcat | grep -i "prism\|dio\|http\|flutter"
```

Or filter for just unhandled exceptions:

```bash
adb logcat *:E | head -30
```

### App opens to a blank / white screen

The app is loading but the API is unreachable. Look for `DioException`
or `Failed host lookup` in the logs. Fix the API URL (§4 / §5).

### App says "connection refused" / "failed to login"

Same diagnosis as above. The API can't be reached from the device.
Walk §4 — laptop firewall, LAN IP, same-Wi-Fi check.

### App force-closes on launch

Usually a build artifact mismatch. From the laptop:

```bash
cd apps/mobile
flutter clean
flutter pub get
flutter run -d <device-id> --dart-define=API_BASE_URL=...
```

### Hot reload (`r`) doesn't apply changes

Hit `R` for a full hot restart. If that still doesn't work, quit
(`q`) and re-launch.

### Emulator is slow / sluggish

- Allocate more RAM to the AVD (Android Studio → Device Manager →
  Edit → Advanced Settings).
- Switch to an x86_64 image (faster than ARM emulation on Intel
  hosts).
- On Apple Silicon Macs, use the `arm64-v8a` system image (native).

### Physical device shows up as "offline"

USB cable is power-only, or the device hasn't trusted the laptop yet.
Replug, accept the trust prompt, run `adb kill-server && adb start-server`.

### `adb devices` shows nothing

```bash
# Windows: install OEM USB drivers from the device manufacturer.
# macOS / Linux: usually plug-and-play. Re-seat the cable, try a
# different USB port (USB-3 ports occasionally misbehave with old
# devices).
```

---

## 8. Reset app data

When the app gets into a weird state (cached old session, stale data,
permissions snapshot), wipe it:

### From within Android settings

Long-press the **PRISM Club** launcher icon → **App info** → **Storage
& cache** → **Clear storage**. The next launch is a fresh install.

### From the laptop

```bash
adb shell pm clear club.prism.mobile
```

This wipes:

- `shared_preferences` (on web only, but irrelevant here).
- `flutter_secure_storage` (Android Keystore-backed JWT).
- Any cached image data, in-app DB, etc.

Next launch shows the login picker as if first run.

### Full uninstall + reinstall

```bash
adb uninstall club.prism.mobile
flutter run -d <device-id> --dart-define=API_BASE_URL=...
```

---

## 9. Known local limitations

These are intentional and tracked in
[NEXT_BACKLOG.md](NEXT_BACKLOG.md):

| Limitation | Reason / fix |
|---|---|
| No push notifications — only in-app | Push is deferred ([NEXT_BACKLOG §2](NEXT_BACKLOG.md)). You see notifications when you open the app, not while it's backgrounded. |
| Deep links from email / SMS open the browser, not the app | App Links / Universal Links not wired yet ([FLUTTER_APP_RELEASE_AUDIT.md §9](FLUTTER_APP_RELEASE_AUDIT.md)). |
| Launcher icon is the default Flutter "F" | Brand assets pending; placeholder documented in [MOBILE_RELEASE_CHECKLIST.md §3](MOBILE_RELEASE_CHECKLIST.md). |
| App label is "PRISM Club" but icon doesn't match | Same — pending brand assets. |
| Camera capture is not implemented | Only gallery image picker. `file_picker` uses Storage Access Framework — no permission prompt on Android 13+. |
| Real password / email signup not available | M13 left auth passwordless for Beta ([NEXT_BACKLOG §1](NEXT_BACKLOG.md)). The login picker is dev/internal use. |
| Logout is client-side only | Stateless JWT; the API call is a no-op stub. The token is deleted from the device's secure storage. ([NEXT_BACKLOG §6](NEXT_BACKLOG.md)). |
| App targets API level 21 floor | Devices older than Android 5.0 (Lollipop) won't install. Modern phones are fine. |

---

## 10. Quick reference card

```bash
# One-time per workstation
docker compose up -d postgres
npx prisma migrate dev && npm run db:seed
npm run api:dev                                         # terminal 1

# Find laptop IP (physical device only)
ipconfig | findstr IPv4                                 # Windows
ifconfig | grep "inet " | grep -v 127.0.0.1             # macOS / Linux

# Emulator
cd apps/mobile && flutter pub get
flutter emulators --launch <emulator-id>
flutter run -d <device-id>                              # no override

# Physical Android device
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=http://<lan-ip>:3000/v1

# Physical device against staging
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=https://api.staging.<your-domain>/v1

# Sideload prebuilt debug APK
adb install -r apps/mobile/build/app/outputs/flutter-apk/app-debug.apk

# Reset app state
adb shell pm clear club.prism.mobile

# Logs
adb logcat | grep -i "prism\|dio\|http"
```
