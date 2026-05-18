#!/usr/bin/env bash
# Sanity check for Android release-signing readiness.
#
# Non-secret — this script NEVER reads the contents of key.properties
# or the keystore. It only inspects file existence, git-ignore status,
# and tracked configuration in build.gradle.kts.
#
# Safe to run in CI and on developer machines that don't (and shouldn't)
# have the upload-key material installed. Absence of key.properties is
# reported as INFO, not as a failure, because dry-run builds without it
# are an intentional state — they produce a debug-signed AAB that's
# rejected by Play Console, which is exactly the warning we want.
#
# What is treated as a real failure:
#   - key.properties NOT covered by .gitignore        (credential leak risk)
#   - *.jks / *.keystore NOT covered by .gitignore    (credential leak risk)
#   - key.properties.example missing or gitignored    (operator has no template)
#   - build.gradle.kts lost the key.properties wiring (release builds break)
#   - build.gradle.kts lost the debug fallback        (dry-run builds break)
#
# Usage:
#   bash scripts/check-release-signing.sh
#   npm run mobile:check-signing
#
# See docs/PLAY_INTERNAL_TESTING.md §2 + docs/ANDROID_RELEASE_DRY_RUN.md
# for the full signing flow.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_DIR="$REPO_ROOT/apps/mobile/android"
KEY_PROPS="$ANDROID_DIR/key.properties"
KEY_PROPS_EXAMPLE="$ANDROID_DIR/key.properties.example"
BUILD_GRADLE="$ANDROID_DIR/app/build.gradle.kts"

FAILS=0
CHECKED=0

if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
    C_GREEN=$'\033[32m'
    C_RED=$'\033[31m'
    C_YELLOW=$'\033[33m'
    C_BOLD=$'\033[1m'
    C_RESET=$'\033[0m'
else
    C_GREEN=""; C_RED=""; C_YELLOW=""; C_BOLD=""; C_RESET=""
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
info() {
    printf "  %sNOTE%s %s\n" "$C_YELLOW" "$C_RESET" "$1"
}
section() {
    printf "\n%s== %s ==%s\n" "$C_BOLD" "$1" "$C_RESET"
}

# -----------------------------------------------------------------------------
# 1. Gitignore safety — credentials must never enter git.
#
# We use `git check-ignore` to ask git itself whether a path would be
# ignored. This works even when the file doesn't exist on disk, so we
# can verify the pattern coverage without creating fake credentials.
# -----------------------------------------------------------------------------
section "Gitignore: keystore + key.properties never tracked"

if git -C "$REPO_ROOT" check-ignore -q "$KEY_PROPS"; then
    pass "apps/mobile/android/key.properties is gitignored"
else
    fail "apps/mobile/android/key.properties is NOT gitignored — staging would leak credentials"
fi

if git -C "$REPO_ROOT" check-ignore -q "$ANDROID_DIR/_probe_.jks"; then
    pass "**/*.jks pattern is gitignored"
else
    fail "**/*.jks is NOT gitignored — keystore files could be accidentally staged"
fi

if git -C "$REPO_ROOT" check-ignore -q "$ANDROID_DIR/_probe_.keystore"; then
    pass "**/*.keystore pattern is gitignored"
else
    fail "**/*.keystore is NOT gitignored — keystore files could be accidentally staged"
fi

if git -C "$REPO_ROOT" check-ignore -q "$KEY_PROPS_EXAMPLE"; then
    fail "key.properties.example is gitignored — operators can't see the template"
else
    pass "key.properties.example is tracked (template visible to operators)"
fi

# -----------------------------------------------------------------------------
# 2. Template + Gradle wiring must remain intact.
# -----------------------------------------------------------------------------
section "Template + Gradle wiring"

if [ -f "$KEY_PROPS_EXAMPLE" ]; then
    pass "apps/mobile/android/key.properties.example exists"
else
    fail "apps/mobile/android/key.properties.example missing — operators have no template to copy"
fi

if [ ! -f "$BUILD_GRADLE" ]; then
    fail "apps/mobile/android/app/build.gradle.kts missing"
else
    if grep -q "keystorePropertiesFile" "$BUILD_GRADLE" \
       && grep -q "hasReleaseKeystore" "$BUILD_GRADLE"; then
        pass "build.gradle.kts loads key.properties when present"
    else
        fail "build.gradle.kts no longer references key.properties — release-signing wiring is broken"
    fi

    if grep -q 'signingConfigs.getByName("debug")' "$BUILD_GRADLE"; then
        pass "build.gradle.kts retains the debug-signing fallback"
    else
        fail "build.gradle.kts missing the debug-signing fallback — release builds may now fail outright when key.properties is absent"
    fi

    if grep -q "key.properties not found" "$BUILD_GRADLE"; then
        pass "build.gradle.kts warns the operator when key.properties is absent"
    else
        fail "build.gradle.kts lost the 'key.properties not found' Gradle warning — debug-signed AABs could ship silently"
    fi
fi

# -----------------------------------------------------------------------------
# 3. Current dry-run state (INFO only — never fails).
#
# This is what the user sees about THIS machine right now. Absence of
# key.properties on a developer / CI machine is the expected default;
# only release-build hosts should have a populated key.properties.
# -----------------------------------------------------------------------------
section "Current host state (dry-run, info only)"

if [ -f "$KEY_PROPS" ]; then
    info "apps/mobile/android/key.properties IS present on this host."
    info "    flutter build appbundle --release will use the operator's upload key."
    info "    This script does NOT read its contents — never log key.properties anywhere."
else
    info "apps/mobile/android/key.properties is ABSENT on this host (expected for dev / CI)."
    info "    flutter build appbundle --release will fall back to the debug keystore,"
    info "    producing an AAB that Play Console rejects at upload time."
    info "    To enable real release signing on a release-build host:"
    info "      cp apps/mobile/android/key.properties.example apps/mobile/android/key.properties"
    info "      # then fill in real values from the team password vault."
fi

# -----------------------------------------------------------------------------
# Summary.
# -----------------------------------------------------------------------------
printf "\n"
if [ "$FAILS" -gt 0 ]; then
    printf "%s%d of %d structural check(s) failed.%s See docs/PLAY_INTERNAL_TESTING.md §2.\n" \
        "$C_RED" "$FAILS" "$CHECKED" "$C_RESET"
    exit 1
fi
printf "%sAll %d structural checks passed.%s Run before every Play upload.\n" \
    "$C_GREEN" "$CHECKED" "$C_RESET"
