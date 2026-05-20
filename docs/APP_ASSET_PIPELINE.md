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

- [ ] `npm run mobile:check-assets` (or `bash scripts/check-mobile-assets.sh`)
      passes — guards against `<inset>` reinjection and missing
      source / generated files. See §9.
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

Forensic audit (the pre-asset gap state, with sha1 hashes of the
Flutter "F" placeholders) is preserved in
[ANDROID_RELEASE_IDENTITY_AUDIT.md](ANDROID_RELEASE_IDENTITY_AUDIT.md)
§3 as of commit `f4433f4`. The brand-asset commit that flipped every
row in this table to ✅ landed on top of that audit — `git log
apps/mobile/assets/branding/` for the exact commit.

| Asset | Path | State |
|---|---|---|
| `mipmap-mdpi/ic_launcher.png` | apps/mobile/android/app/src/main/res/ | ✅ PRISM purple-gradient legacy icon |
| `mipmap-hdpi/ic_launcher.png` | … | ✅ PRISM purple-gradient legacy icon |
| `mipmap-xhdpi/ic_launcher.png` | … | ✅ PRISM purple-gradient legacy icon |
| `mipmap-xxhdpi/ic_launcher.png` | … | ✅ PRISM purple-gradient legacy icon |
| `mipmap-xxxhdpi/ic_launcher.png` | … | ✅ PRISM purple-gradient legacy icon |
| Adaptive icon XML | `mipmap-anydpi-v26/ic_launcher.xml` | ✅ background + foreground + monochrome (no insets — matches brand handoff) |
| Adaptive icon foreground | `drawable-*/ic_launcher_foreground.png` (5 densities) | ✅ White prism, transparent bg |
| Adaptive icon background | `drawable-*/ic_launcher_background.png` (5 densities) | ✅ Purple gradient |
| Adaptive icon monochrome | `drawable-*/ic_launcher_monochrome.png` (5 densities) | ✅ Single-color silhouette (Android 13+ themed) |
| Launch background | `drawable/launch_background.xml` + `drawable-v21/…` | ✅ `#6D28D9` fill + centered splash mark |
| Android 12+ splash | `values-v31/styles.xml` + `drawable-*/android12splash.png` | ✅ `windowSplashScreenBackground = #6D28D9` + animated icon |
| iOS app icon set | n/a | ❌ iOS scaffold not present (defer per FLUTTER_NATIVE_SETUP.md §3) |
| Launcher label | `values/strings.xml` `app_name` | ✅ "PRISM Club" |

### Composite legacy icon

`flutter_launcher_icons` reads `image_path_android` to produce the
legacy `mipmap-*/ic_launcher.png` densities used by API < 26 launchers
(no adaptive-icon XML support). The brand foreground PNG is
transparent, so feeding it directly would make legacy launchers show a
floating prism with no background. We pre-composite foreground over
background with Pillow:

```bash
cd apps/mobile/assets/branding
python -c "
from PIL import Image
bg = Image.open('adaptive_icon_background.png').convert('RGBA')
fg = Image.open('adaptive_icon_foreground.png').convert('RGBA')
Image.alpha_composite(bg, fg).save('app_icon_legacy.png', optimize=True)
"
```

`pubspec.yaml`'s `flutter_launcher_icons.image_path_android` points at
that composite. Regenerate the composite whenever either source layer
changes, then re-run `dart run flutter_launcher_icons`.

### Adaptive icon XML — no-inset hand-tweak

`flutter_launcher_icons` 0.14 always emits the adaptive-icon XML with
a 16% `<inset>` on the foreground + monochrome layers, assuming the
input PNG is full-bleed and needs a safe-zone margin. Our brand source
PNGs are pre-sized for the 66dp/108dp safe-zone (see
`assets/branding/README.md`), so adding another inset shrinks the
glyph past the designer-intended size.

After every `dart run flutter_launcher_icons`, hand-restore
`mipmap-anydpi-v26/ic_launcher.xml` to the no-inset variant:

```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
```

If the brand source is ever redrawn as a full-bleed canvas, drop this
note and accept the plugin default.

---

## 9. Drift guard — `scripts/check-mobile-assets.sh`

The two operator footguns above (silent `<inset>` reinjection + a
forgotten regen step) fail loudly in
[`scripts/check-mobile-assets.sh`](../scripts/check-mobile-assets.sh).
Runs in Git Bash on Windows and bash on Linux / macOS, no extra deps.

```bash
# From repo root:
bash scripts/check-mobile-assets.sh
# Or via the wrapper npm script:
npm run mobile:check-assets
```

What it asserts (39 checks):

- `mipmap-anydpi-v26/ic_launcher.xml` has no `<inset>` elements
  outside XML comments (so explanatory prose about insets doesn't
  trigger a false positive).
- All five brand source PNGs exist under `apps/mobile/assets/branding/`
  (including the Pillow-composited `app_icon_legacy.png`).
- Legacy launcher mipmaps exist at all five densities.
- Adaptive icon foreground / background / monochrome layers exist at
  all five densities.
- Pre-Android-12 `splash.png` and Android 12+ `android12splash.png`
  exist at all five densities.
- `launch_background.xml` (+ `drawable-v21/…`) and `values-v31/styles.xml`
  exist (theme wiring).

Exit code is non-zero on any failure with a one-line FAIL reason per
broken check and a tail summary like:

```
1 of 39 check(s) failed. See docs/APP_ASSET_PIPELINE.md §8 for the operator flow.
```

Run it as part of the asset refresh flow (§4) and again before
shipping any release AAB.

---

## 10. Font asset verification (Pretendard)

The brand asset pipeline above handles icon + splash. The Pretendard
variable font travels alongside via a separate asset path. Verify
once per release that the binary still ships intact.

State at last verification (`docs(mobile): confirm pretendard binary presence`):

| Check | Command | Expected |
|---|---|---|
| Binary tracked | `git ls-files apps/mobile/assets/fonts` | Lists `PretendardVariable.ttf` + `Pretendard-LICENSE.txt`. |
| Binary size | `wc -c < apps/mobile/assets/fonts/PretendardVariable.ttf` | `6739336` (current production hash; bump only when intentionally upgrading the font). |
| Pubspec registration | `grep -A3 'family: Pretendard' apps/mobile/pubspec.yaml` | `asset: assets/fonts/PretendardVariable.ttf`. |
| Theme wiring | `grep -nE "PrismFonts.body|fontFamily: PrismFonts" apps/mobile/lib/app/theme.dart` | `ThemeData.fontFamily = PrismFonts.body` at the root; every TextTheme entry resolves through `PrismType`. |
| `PrismFonts.body` value | `grep "static const body" apps/mobile/lib/app/design_tokens.dart` | `static const body = 'Pretendard';` |
| Release AAB packaging | `unzip -l build/app/outputs/bundle/release/app-release.aab \| grep -i pretendard` | One entry at `base/assets/flutter_assets/assets/fonts/PretendardVariable.ttf` matching the source byte count. The variable font is NOT tree-shaken (unlike `MaterialIcons-Regular.otf` which Flutter shrinks). |

If any row drifts, treat it as the same severity as a brand-icon
drift (operator-blocking before Play upload). The check is
verification-only — there is no script wrapper today because the
checks are run once per release cycle, not on every commit. If that
changes, fold these into `scripts/check-mobile-assets.sh` alongside
the existing icon / splash assertions.
