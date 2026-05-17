# PRISM Club — App Asset Pipeline

What the launcher icon and splash assets need to look like before the
first Play upload, where they live, and how to generate the platform
artefacts from one source. **No final brand visuals are invented in
this document.**

> Current state (commit `ca03bf4`): every Android `mipmap-*/ic_launcher.png`
> is the default Flutter "F" icon Flutter shipped from `flutter create`.
> The launch background is a plain white drawable. The app label is
> "PRISM Club" (set in [strings.xml](../apps/mobile/android/app/src/main/res/values/strings.xml))
> so the launcher already shows the right name, but the icon next to
> it is still the placeholder.

Pairs with:

- [FLUTTER_APP_RELEASE_AUDIT.md](FLUTTER_APP_RELEASE_AUDIT.md) §8 —
  the audit that flagged this work.
- [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) §3 — the
  checklist gate this doc unblocks.
- [ANDROID_DEVICE_RUNBOOK.md](ANDROID_DEVICE_RUNBOOK.md) — already
  notes the placeholder state under "Known local limitations."

---

## 1. Required source files

Hand off these from the design owner. The pipeline regenerates every
platform artefact from this set — committing the intermediate PNG
densities by hand is **not** the recommended path.

| File | Format | Size | Purpose |
|---|---|---|---|
| `prism-club-icon.svg` (or `.png` at ≥ 1024×1024) | vector or square PNG | 1024×1024 minimum; SVG preferred | Full-bleed launcher icon. Designs should account for the **66 dp safe zone** (≈ 432 px / 1024 px) — Android adaptive icons crop to a system-defined mask. |
| `prism-club-icon-foreground.svg` (or `.png`) | square | 1024×1024 | Foreground layer of the **adaptive icon** (108 dp foreground × 108 dp background, 72 dp visible — anything outside the safe zone is cropped). |
| `prism-club-icon-background.png` (or solid hex) | square or color | 1024×1024 / hex | Background layer of the adaptive icon. Can be a flat color (`#000000`-style hex) instead of a PNG. |
| `prism-club-splash.png` | square | 1152×1152 minimum | Centered splash artwork. Use the same artwork at 4x for the iOS launch image set later. |
| `prism-club-splash-background.png` (or solid hex) | full | matches device size or solid hex | Background fill behind the splash. Solid hex recommended (`#FFFFFF` light, `#0E0E10` dark — placeholders; design owner decides). |

**Commit destination:** `apps/mobile/assets/branding/` (folder doesn't
exist yet — create it when the first source asset lands). Sources live
in git so the generated platform artefacts are reproducible.

---

## 2. Android: launcher icon sizes

Android needs the icon at five densities **at runtime**. We will NOT
hand-author each density — the recommended tool generates them all
from one source.

| Density bucket | Px |
|---|---|
| mdpi | 48 × 48 |
| hdpi | 72 × 72 |
| xhdpi | 96 × 96 |
| xxhdpi | 144 × 144 |
| xxxhdpi | 192 × 192 |

These end up at:

```
apps/mobile/android/app/src/main/res/
  mipmap-mdpi/ic_launcher.png
  mipmap-hdpi/ic_launcher.png
  mipmap-xhdpi/ic_launcher.png
  mipmap-xxhdpi/ic_launcher.png
  mipmap-xxxhdpi/ic_launcher.png
```

Each is overwritten in place by the generation step in §4.

---

## 3. Android: adaptive icon (API 26+)

Play recommends adaptive icons since Android 8 (Oreo, API 26). The
adaptive icon is a **layered** asset: foreground + background, sized
to 108 dp each, with the OS launcher cropping to a per-OEM mask
(circle / squircle / rounded square / teardrop).

Files to generate:

```
apps/mobile/android/app/src/main/res/
  mipmap-anydpi-v26/
    ic_launcher.xml             ← layer list pointing at the two below
  drawable/
    ic_launcher_foreground.xml  ← vector or @mipmap reference
  values/
    ic_launcher_background.xml  ← color, e.g. #FFFFFF
```

Sample `mipmap-anydpi-v26/ic_launcher.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
```

Devices on API < 26 fall back to the per-density `mipmap-*/ic_launcher.png`
from §2 — both layers must ship together for full coverage.

---

## 4. Generation pipeline (recommended)

Two community Flutter plugins generate everything from one
`pubspec.yaml` config block, so nobody hand-crops PNGs:

| Plugin | What it generates |
|---|---|
| `flutter_launcher_icons` | Per-density `mipmap-*/ic_launcher.png` + adaptive-icon XML on Android + `Assets.xcassets/AppIcon.appiconset/` on iOS. |
| `flutter_native_splash` | `launch_background.xml` for Android + LaunchScreen storyboard for iOS + web favicon. |

Add to `apps/mobile/pubspec.yaml` `dev_dependencies` **when the source
assets land** (do not add as part of this planning PR):

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.4
  flutter_native_splash: ^2.4.4

flutter_launcher_icons:
  android: "ic_launcher"
  ios: true
  image_path: "assets/branding/prism-club-icon.png"
  adaptive_icon_background: "#FFFFFF"           # or a color resource
  adaptive_icon_foreground: "assets/branding/prism-club-icon-foreground.png"

flutter_native_splash:
  color: "#FFFFFF"
  image: "assets/branding/prism-club-splash.png"
  android_12:
    color: "#FFFFFF"
    image: "assets/branding/prism-club-splash.png"
```

Then run, from `apps/mobile/`:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Each command rewrites the platform asset files in place. Commit the
output as part of the same PR — the regenerated mipmap PNGs + XMLs
are the source of truth at build time, while the SVG sources stay
under `assets/branding/` for reproducibility.

---

## 5. Manual paths (if the plugins can't be used)

If for some reason the plugins are off-limits (e.g. dependency policy
forbids them), generate the per-density PNGs in any image editor and
drop them at the paths in §2 and §3. Verify with:

```bash
cd apps/mobile/android
./gradlew assembleDebug -q
adb install -r ../build/app/outputs/flutter-apk/app-debug.apk
# Then check the launcher — the new icon should appear.
```

The XML files in §3 can be hand-authored from the templates above.

---

## 6. iOS — future notes

Add when the macOS engineer creates `apps/mobile/ios/` (see
[FLUTTER_NATIVE_SETUP.md](FLUTTER_NATIVE_SETUP.md) §3):

- iOS app icon set lives at
  `ios/Runner/Assets.xcassets/AppIcon.appiconset/` and requires
  multiple sizes (20pt @1x/2x/3x, 29pt, 40pt, 60pt, 76pt @1x/2x,
  83.5pt @2x, 1024pt for the App Store listing).
- `flutter_launcher_icons` regenerates the appiconset alongside the
  Android mipmaps when `ios: true` is set, so the same source SVG
  feeds both platforms.
- iOS launch storyboard:
  `ios/Runner/Base.lproj/LaunchScreen.storyboard`. Flutter's default
  is a plain background — `flutter_native_splash` rewrites it from
  the splash config above.

---

## 7. QA checklist

After regenerating assets:

- [ ] `flutter build apk --debug` succeeds.
- [ ] Launcher icon on a fresh install (`adb shell pm clear` →
      re-launch) shows the brand mark, not the Flutter "F".
- [ ] On an Android 8+ device, long-press the launcher icon → the
      shape matches the OEM's adaptive-icon mask (circle on Pixel,
      squircle on One UI, etc.). If the shape looks wrong, the
      foreground/background safe-zones in the source SVG need
      tightening.
- [ ] Cold-start splash shows the brand background + centered art for
      ~500–1500 ms, then transitions to the Flutter UI without a
      visible white flash.
- [ ] Dark mode launcher icon — Android 13+ allows themed icons via
      `mipmap-anydpi-v26/ic_launcher.xml` `<monochrome>` layer. Add
      a monochrome variant in the same source set if the brand has
      a single-color treatment.
- [ ] Verify the regenerated PNGs are not absurdly large
      (`du -sh apps/mobile/android/app/src/main/res/mipmap-xxxhdpi/`
      should be < 50 KB).

---

## 8. Status snapshot (today)

| Asset | Path | State |
|---|---|---|
| `mipmap-mdpi/ic_launcher.png` | apps/mobile/android/app/src/main/res/ | Default Flutter "F" |
| `mipmap-hdpi/ic_launcher.png` | … | Default Flutter "F" |
| `mipmap-xhdpi/ic_launcher.png` | … | Default Flutter "F" |
| `mipmap-xxhdpi/ic_launcher.png` | … | Default Flutter "F" |
| `mipmap-xxxhdpi/ic_launcher.png` | … | Default Flutter "F" |
| Adaptive icon XML | `mipmap-anydpi-v26/` | ❌ Missing |
| Adaptive icon foreground | `drawable/ic_launcher_foreground` | ❌ Missing |
| Adaptive icon background | `values/ic_launcher_background.xml` | ❌ Missing |
| Launch background | `drawable/launch_background.xml` | Plain white (`@android:color/white`) |
| iOS app icon set | n/a | iOS scaffold not present |
| Launcher label | `values/strings.xml` `app_name` | ✅ "PRISM Club" |

When the design owner hands over the source files in §1, this status
table flips to ✅ row-by-row after a single
`dart run flutter_launcher_icons` + commit.
