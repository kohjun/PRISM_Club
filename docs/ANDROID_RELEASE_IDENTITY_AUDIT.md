# PRISM Club — Android Release Identity Audit

A point-in-time snapshot of the Android app's release identity — package
metadata, launcher icon, splash, manifest, and required brand assets —
so the next operator with brand source files knows exactly which paths
to populate. **No code is changed beyond documentation by this audit.**

> Snapshot taken against commit `f4433f4 fix(mobile): harden design refresh visual qa`
> on 2026-05-18. Working tree clean before this commit; only Flutter
> mobile / Android metadata / docs changed.

> **Status update (2026-05-18):** every §3 gap (launcher icon,
> adaptive icon, monochrome icon, splash drawable, branding source
> folder) was resolved in a follow-up commit that landed brand source
> PNGs under `apps/mobile/assets/branding/` and regenerated the
> Android resources via `flutter_launcher_icons` + `flutter_native_splash`.
> Current status table is in
> [APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md) §8. The gap snapshot
> below is preserved verbatim for forensic context — sha1s + dimensions
> describe the **pre-asset state**, not the current tree.

Pairs with:

- [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) §1, §3, §7 —
  the go / no-go gates this audit feeds.
- [APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md) — the full generation
  pipeline for icon + splash once brand source files land.
- [ANDROID_RELEASE_DRY_RUN.md](ANDROID_RELEASE_DRY_RUN.md) — signing
  state (parallel point-in-time forensic doc).
- [FLUTTER_APP_RELEASE_AUDIT.md](FLUTTER_APP_RELEASE_AUDIT.md) §2 — the
  original audit (commit `10d7ab6`) that this snapshot tracks against.

---

## 1. Scope

What's inside:

- Android app label (`<application android:label>`).
- `applicationId`, `namespace`.
- Launcher icon assets (`mipmap-*/ic_launcher.png` + adaptive icon XML).
- Splash drawable (`drawable/launch_background.xml`,
  `drawable-v21/launch_background.xml`).
- Splash theme wiring (`values/styles.xml`, `values-night/styles.xml`).
- Manifest permissions + `<queries>`.

What's out of scope (covered elsewhere):

- Signing — see [ANDROID_RELEASE_DRY_RUN.md](ANDROID_RELEASE_DRY_RUN.md).
- Versioning — see [MOBILE_VERSIONING.md](MOBILE_VERSIONING.md).
- iOS scaffold — Windows host cannot produce it; see
  [FLUTTER_NATIVE_SETUP.md](FLUTTER_NATIVE_SETUP.md) §3.
- Brand asset *generation* — see
  [APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md) for source-file
  requirements, generation tools, and commit destinations.

---

## 2. Resolved since the original audit

These items moved from ❌ / ⚠️ in
[FLUTTER_APP_RELEASE_AUDIT.md](FLUTTER_APP_RELEASE_AUDIT.md) §2 to ✅
in earlier commits — re-verified at this snapshot:

| Item | State at snapshot | Resolved in |
|---|---|---|
| `applicationId` | `club.prism.mobile` in [`build.gradle.kts:50`](../apps/mobile/android/app/build.gradle.kts) | `464448e chore(mobile): set android app identity baseline` |
| `namespace` | `club.prism.mobile` in [`build.gradle.kts:36`](../apps/mobile/android/app/build.gradle.kts) | `464448e` |
| `android:label` | `@string/app_name` → **"PRISM Club"** in [`values/strings.xml`](../apps/mobile/android/app/src/main/res/values/strings.xml) | `464448e` |
| `INTERNET` permission | Declared in main `AndroidManifest.xml:10` (not only the debug overlay) | `c352973 chore(mobile): audit android permissions` |
| `url_launcher` `<queries>` | `http` + `https` `VIEW` intents declared in `AndroidManifest.xml:62-69` | `c352973` |
| `PROCESS_TEXT` `<queries>` | Declared in `AndroidManifest.xml:50-53` | Flutter scaffold (unchanged) |
| Java + Kotlin target | 17 (both `compileOptions` and `kotlinOptions`) | Initial scaffold |
| Splash theme wiring | `LaunchTheme` → `windowBackground = @drawable/launch_background`; `NormalTheme` meta-data set on `MainActivity` | Flutter scaffold (unchanged) |
| Release signing fallback | `key.properties`-or-debug pattern with operator warning in `build.gradle.kts:73-91` | `ca03bf4 chore(mobile): wire android release signing template` |

No regressions detected. None of the audited files have moved or changed
shape since their resolving commits.

---

## 3. Outstanding gaps

Each row below is **blocked on operator action** — brand source files,
explicit SDK pinning, or design decision. None of these can be safely
"fixed" in code alone, which is why this audit changes documentation
rather than asset bits.

### 3.1 Launcher icon — still the Flutter "F" placeholder

Every density bucket ships the default `flutter create` PNG. Verified at
snapshot (file sizes + sha1):

| Path | Pixel size | sha1 | State |
|---|---|---|---|
| `apps/mobile/android/app/src/main/res/mipmap-mdpi/ic_launcher.png` | 48 × 48 | `7d18d43e4eb8fe59ea46cf51cc659be6a7f4cab5` | Default Flutter "F" |
| `…/mipmap-hdpi/ic_launcher.png` | 72 × 72 | `ea2b064031f64e11892f4dedc3e43c373b97c645` | Default Flutter "F" |
| `…/mipmap-xhdpi/ic_launcher.png` | 96 × 96 | `45963ffb5dda7e9df4a26eda4459111d7bf1fe94` | Default Flutter "F" |
| `…/mipmap-xxhdpi/ic_launcher.png` | 144 × 144 | `e373f4f6fa753c8a6df8465b1a70f2a749c202c8` | Default Flutter "F" |
| `…/mipmap-xxxhdpi/ic_launcher.png` | 192 × 192 | `dd0452802ca0cd6c81b9b5982aeb56b051b73829` | Default Flutter "F" |

Unblock path: [APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md) §1 + §4
(`flutter_launcher_icons` regenerates all five from one source).

### 3.2 Adaptive icon (API 26+) — not configured

The following Android resource files do **not** exist in the repo:

```
apps/mobile/android/app/src/main/res/
  mipmap-anydpi-v26/
    ic_launcher.xml             ← missing (adaptive-icon layer list)
  drawable/
    ic_launcher_foreground.xml  ← missing (foreground vector / @mipmap ref)
  values/
    ic_launcher_background.xml  ← missing (background color resource)
```

Devices on API < 26 fall through to §3.1's per-density PNGs, so adding
only adaptive XML without replacing the §3.1 PNGs still leaves older
launchers showing the "F". Both must ship together. Sample XML in
[APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md) §3.

Android 13+ themed-icon (`<monochrome>` layer in the adaptive XML) is
optional but recommended — handled by the same source set if the brand
provides a single-color treatment.

### 3.3 Splash — plain white scaffold

```
apps/mobile/android/app/src/main/res/drawable/launch_background.xml
```

Current content (Flutter scaffold default):

```xml
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/white" />
</layer-list>
```

The API-21+ overlay
(`drawable-v21/launch_background.xml`) uses `?android:colorBackground`
(system theme background, light = white, dark = black). No brand color,
no centered brand mark.

The splash *theme* wiring is correct — `values/styles.xml` and
`values-night/styles.xml` both point `LaunchTheme.windowBackground` at
`@drawable/launch_background`, so the drawable swap is a 1-line change
once the source asset lands. **No theme fix required at this audit.**

Unblock path: `flutter_native_splash:create` regenerates both
`launch_background.xml` files from a single source PNG + background
color — see [APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md) §4.

### 3.4 `compileSdk` / `minSdk` / `targetSdk` not explicitly pinned

```
compileSdk = flutter.compileSdkVersion
minSdk     = flutter.minSdkVersion
targetSdk  = flutter.targetSdkVersion
```

These inherit from whichever Flutter SDK version compiled the build.
Play Console requires apps to ship targeting **at least last August's
API level** ([Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878)),
so inheriting from `flutter.*` is fine *today* but the release ticket
must pin an explicit number to lock release-build behavior.

This audit does **not** change these values. Pinning is deliberate
release-binding work and belongs in the release-ticket PR, not this
audit. Tracked in [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md)
§1 (already marked `[ ]`).

### 3.5 Branding source folder doesn't exist

```
apps/mobile/assets/branding/   ← does not exist
```

When the design owner hands over source SVG / PNG, they go here so the
pipeline is reproducible. Listed under "destination" in
[APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md) §1.

---

## 4. Required brand asset files (operator action list)

The exact paths the design + ops owners need to populate. **None of
these is created by code in this audit** — the explicit policy is
"브랜드 asset이 repo에 없으면 asset 생성하지 말고 필요한 파일 목록과 경로를 문서화".

### 4.1 Source files (committed first, in `apps/mobile/assets/branding/`)

| Path | Format | Min size | Notes |
|---|---|---|---|
| `apps/mobile/assets/branding/prism-club-icon-foreground.svg` (or `.png`) | square, transparent bg | 1024 × 1024 | Adaptive icon foreground layer. Visible 66 dp safe-zone — anything outside is cropped by the OEM mask. |
| `apps/mobile/assets/branding/prism-club-icon-background.png` (or solid hex) | square | 1024 × 1024 | Adaptive icon background. Solid hex (e.g. `#FFFFFF`) is preferred. |
| `apps/mobile/assets/branding/prism-club-icon.png` | square | 1024 × 1024 | Full-bleed icon for the legacy `ic_launcher.png` densities + iOS app icon set. |
| `apps/mobile/assets/branding/prism-club-splash.png` | square (centered art) | 1152 × 1152 | Centered splash artwork. |
| `apps/mobile/assets/branding/prism-club-splash.color` (or doc hex) | hex literal in pubspec | n/a | Splash background fill. Stored as a hex string in pubspec, not a separate PNG. |

### 4.2 Generated files (regenerated by tooling — listed for traceability)

Operators run `dart run flutter_launcher_icons` +
`dart run flutter_native_splash:create` from `apps/mobile/` after the
§4.1 source files land. The tools rewrite **these** files in place:

| Path | Tool |
|---|---|
| `apps/mobile/android/app/src/main/res/mipmap-mdpi/ic_launcher.png` | `flutter_launcher_icons` |
| `apps/mobile/android/app/src/main/res/mipmap-hdpi/ic_launcher.png` | `flutter_launcher_icons` |
| `apps/mobile/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` | `flutter_launcher_icons` |
| `apps/mobile/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` | `flutter_launcher_icons` |
| `apps/mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` | `flutter_launcher_icons` |
| `apps/mobile/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` | `flutter_launcher_icons` (new file) |
| `apps/mobile/android/app/src/main/res/drawable/ic_launcher_foreground.xml` (or PNG variants per density) | `flutter_launcher_icons` (new file) |
| `apps/mobile/android/app/src/main/res/values/ic_launcher_background.xml` | `flutter_launcher_icons` (new file) |
| `apps/mobile/android/app/src/main/res/drawable/launch_background.xml` | `flutter_native_splash` |
| `apps/mobile/android/app/src/main/res/drawable-v21/launch_background.xml` | `flutter_native_splash` |
| `apps/mobile/android/app/src/main/res/values/styles.xml` (only `windowSplashScreen*` attrs on Android 12+) | `flutter_native_splash` |
| `apps/mobile/android/app/src/main/res/values-night/styles.xml` | `flutter_native_splash` |
| `apps/mobile/android/app/src/main/res/drawable*/launch_background*` (additional density variants) | `flutter_native_splash` |

The two plugin dependencies themselves
(`flutter_launcher_icons: ^0.14.4`, `flutter_native_splash: ^2.4.4`) get
added to `apps/mobile/pubspec.yaml` `dev_dependencies` when the operator
runs the regeneration — **not** in this audit. Adding them before the
source assets exist would only add dependency surface with no
deliverable.

---

## 5. Verification at snapshot

Run from `apps/mobile/`:

```
flutter analyze                 → info-only items (unchanged baseline)
flutter test                    → all widget tests green
flutter build apk --debug       → builds (debug-signed)
flutter build appbundle --release → builds (debug-signed; Play-rejected per §3 of ANDROID_RELEASE_DRY_RUN.md)
```

Visible launcher state on a debug install:

- App label on the launcher reads **"PRISM Club"** (from
  `values/strings.xml`, wired via `android:label="@string/app_name"`).
- Icon next to the label is the Flutter "F" placeholder.
- Cold-start splash is plain white (light theme) / black-or-system
  background (dark theme via the v21 overlay).

---

## 6. What this audit changed

- `docs/ANDROID_RELEASE_IDENTITY_AUDIT.md` (this file, new).
- `docs/MOBILE_RELEASE_CHECKLIST.md` §1 + §3 — cross-link to this audit.
- `docs/APP_ASSET_PIPELINE.md` §8 — snapshot reference updated to point
  at this audit's commit so the status table doesn't drift.

No application code touched. No assets touched. No Gradle / manifest /
theme / strings file touched. The audit is documentation-only — the
*next* PR (when brand sources land) flips every ❌ row above to ✅ in a
single `dart run` + commit.
