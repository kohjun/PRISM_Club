#!/usr/bin/env bash
# Guard the Android brand asset pipeline against silent drift between
# `flutter_launcher_icons` / `flutter_native_splash` regenerations and
# the brand-correct shape committed to the repo.
#
# Two failure modes this catches:
#
#   (1) `flutter_launcher_icons` 0.14 reinjects `<inset android:inset="16%">`
#       around the foreground + monochrome layers in
#       `mipmap-anydpi-v26/ic_launcher.xml` every time it runs. The brand
#       handoff (assets/branding/README.md) explicitly wants no insets —
#       the source PNGs are pre-sized for the 66dp/108dp safe-zone.
#       Re-running the generator without hand-restoring the XML silently
#       shrinks the glyph.
#
#   (2) An operator deletes / forgets to regenerate one of the layered
#       Android resources, leaving the launcher pulling a placeholder
#       or a transparent layer that renders as a checkerboard on
#       certain OEM launchers.
#
# Both fail loudly here so CI / pre-commit catches them before the AAB
# is uploaded to Play. See docs/APP_ASSET_PIPELINE.md §8 for the
# operator flow and docs/ANDROID_RELEASE_IDENTITY_AUDIT.md §3 for the
# forensic context.
#
# Usage (Git Bash on Windows, bash on Linux/macOS):
#
#   bash scripts/check-mobile-assets.sh
#
# Or, from the repo root via npm:
#
#   npm run mobile:check-assets

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES_DIR="$REPO_ROOT/apps/mobile/android/app/src/main/res"
ASSETS_DIR="$REPO_ROOT/apps/mobile/assets/branding"
ADAPTIVE_XML="$RES_DIR/mipmap-anydpi-v26/ic_launcher.xml"

FAILS=0
CHECKED=0

# Disable color output when stdout isn't a TTY (CI logs) or when
# NO_COLOR is set (https://no-color.org/).
if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
    C_GREEN=$'\033[32m'
    C_RED=$'\033[31m'
    C_BOLD=$'\033[1m'
    C_RESET=$'\033[0m'
else
    C_GREEN=""; C_RED=""; C_BOLD=""; C_RESET=""
fi

pass() {
    CHECKED=$((CHECKED + 1))
    printf "  %sOK%s   %s\n" "$C_GREEN" "$C_RESET" "$1"
}

fail() {
    CHECKED=$((CHECKED + 1))
    FAILS=$((FAILS + 1))
    printf "  %sFAIL%s %s\n" "$C_RED" "$C_RESET" "$1"
}

section() {
    printf "\n%s== %s ==%s\n" "$C_BOLD" "$1" "$C_RESET"
}

require_file() {
    local label="$1"
    local path="$2"
    if [ -f "$path" ]; then
        pass "$label"
    else
        fail "missing: $label"
    fi
}

# -----------------------------------------------------------------------------
# 1. Adaptive icon XML must not contain `<inset>` wrappers. We strip
#    XML comments first so explanatory prose about insets in the file
#    header doesn't trigger a false positive — only inset elements in
#    actual markup count. The awk script toggles an `in_comment` flag
#    so multi-line `<!-- ... -->` blocks are handled correctly.
# -----------------------------------------------------------------------------
section "Adaptive icon XML (mipmap-anydpi-v26)"
if [ ! -f "$ADAPTIVE_XML" ]; then
    fail "missing: mipmap-anydpi-v26/ic_launcher.xml"
else
    stripped=$(awk '
        BEGIN { in_comment = 0 }
        {
            line = $0
            while (1) {
                if (in_comment) {
                    end = index(line, "-->")
                    if (end == 0) { line = ""; break }
                    line = substr(line, end + 3)
                    in_comment = 0
                } else {
                    start = index(line, "<!--")
                    if (start == 0) break
                    end = index(line, "-->")
                    if (end == 0) {
                        line = substr(line, 1, start - 1)
                        in_comment = 1
                        break
                    }
                    line = substr(line, 1, start - 1) substr(line, end + 3)
                }
            }
            print line
        }
    ' "$ADAPTIVE_XML")

    if printf "%s" "$stripped" | grep -q "<inset"; then
        fail "mipmap-anydpi-v26/ic_launcher.xml contains <inset> — flutter_launcher_icons reinjects 16% insets every regen. Restore the no-inset variant per docs/APP_ASSET_PIPELINE.md §8."
    else
        pass "mipmap-anydpi-v26/ic_launcher.xml has no <inset> wrappers"
    fi
fi

# -----------------------------------------------------------------------------
# 2. Brand source PNGs under apps/mobile/assets/branding/.
# -----------------------------------------------------------------------------
section "Brand source PNGs (apps/mobile/assets/branding/)"
for f in \
    adaptive_icon_foreground.png \
    adaptive_icon_background.png \
    monochrome_icon.png \
    splash_mark.png \
    app_icon_legacy.png
do
    require_file "assets/branding/$f" "$ASSETS_DIR/$f"
done

# -----------------------------------------------------------------------------
# 3. Legacy launcher PNGs (used by API < 26 launchers, all 5 densities).
# -----------------------------------------------------------------------------
section "Legacy launcher mipmaps (5 densities)"
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    require_file "mipmap-$d/ic_launcher.png" "$RES_DIR/mipmap-$d/ic_launcher.png"
done

# -----------------------------------------------------------------------------
# 4. Adaptive icon layers (5 densities × 3 layers = 15 PNGs).
# -----------------------------------------------------------------------------
section "Adaptive icon layers (5 densities × 3 layers)"
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    for layer in foreground background monochrome; do
        require_file \
            "drawable-$d/ic_launcher_$layer.png" \
            "$RES_DIR/drawable-$d/ic_launcher_$layer.png"
    done
done

# -----------------------------------------------------------------------------
# 5. Splash drawables — pre-Android-12 (splash.png) + Android 12+
#    (android12splash.png) at every density.
# -----------------------------------------------------------------------------
section "Splash drawables (pre-12 + Android 12+)"
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    require_file "drawable-$d/splash.png" "$RES_DIR/drawable-$d/splash.png"
    require_file \
        "drawable-$d/android12splash.png" \
        "$RES_DIR/drawable-$d/android12splash.png"
done

# launch_background.xml — wires the pre-12 splash drawable into the
# LaunchTheme. Both the default and v21 variants must exist.
section "Splash theme wiring"
require_file \
    "drawable/launch_background.xml" \
    "$RES_DIR/drawable/launch_background.xml"
require_file \
    "drawable-v21/launch_background.xml" \
    "$RES_DIR/drawable-v21/launch_background.xml"
require_file \
    "values-v31/styles.xml (Android 12+ splash-screen API)" \
    "$RES_DIR/values-v31/styles.xml"

# -----------------------------------------------------------------------------
# Summary + exit.
# -----------------------------------------------------------------------------
printf "\n"
if [ "$FAILS" -gt 0 ]; then
    printf "%s%d of %d check(s) failed.%s " \
        "$C_RED" "$FAILS" "$CHECKED" "$C_RESET"
    printf "See docs/APP_ASSET_PIPELINE.md §8 for the operator flow.\n"
    exit 1
fi
printf "%sAll %d checks passed.%s\n" "$C_GREEN" "$CHECKED" "$C_RESET"
