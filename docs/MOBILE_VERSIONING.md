# PRISM Club — Mobile Versioning Policy

How `versionName` and `versionCode` (Android) and `CFBundleShortVersionString`
+ `CFBundleVersion` (iOS) are bumped across PRISM Club mobile releases.
Goal: deterministic, monotonic, and reversible-by-bump-only across every
release track.

Pairs with:

- [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) §1 + §2 —
  where the values plug into the release build.
- [PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md) §4 + §6 — first
  Play upload's versioning gates.
- [ANDROID_RELEASE_DRY_RUN.md](ANDROID_RELEASE_DRY_RUN.md) — the build
  pipeline that emits these values into the AAB.

---

## 1. Source of truth

A single `version:` line in `apps/mobile/pubspec.yaml` feeds both
platforms.

```yaml
version: 0.1.0+1
#        ^^^^^ ^
#        |     +-- build number (Android versionCode / iOS CFBundleVersion)
#        +-- display name (Android versionName / iOS CFBundleShortVersionString)
```

The Flutter Gradle plugin parses this:

- `versionName` ← the part before `+`.
- `versionCode` ← the integer after `+`.

iOS Xcode uses Flutter's `Generated.xcconfig` (`FLUTTER_BUILD_NAME` and
`FLUTTER_BUILD_NUMBER`) for the same mapping.

**Do not hardcode `versionName` / `versionCode` in `build.gradle.kts`
or the iOS `Info.plist`.** Both currently derive from `pubspec.yaml`
via `flutter.versionName` / `flutter.versionCode` (confirmed in
`apps/mobile/android/app/build.gradle.kts:55-56`). Hardcoding would
make iOS and Android drift; the single-source-of-truth shape is
intentional.

---

## 2. Current state

| Field | Value | Source |
|---|---|---|
| `version` | `0.1.0+1` | `apps/mobile/pubspec.yaml:4` |
| versionName (Android) | `0.1.0` | derived |
| versionCode (Android) | `1` | derived |
| CFBundleShortVersionString (iOS) | `0.1.0` | derived (iOS scaffold not present yet) |
| CFBundleVersion (iOS) | `1` | derived |

`0.1.0+1` is the right Beta starting point — no need to bump it
before the first upload. The first Play Internal upload increments
to `0.1.0+2` to satisfy Play's "every upload needs a new versionCode"
rule.

---

## 3. Format

### 3.1 `versionName` — display semver

`MAJOR.MINOR.PATCH`, displayed to users in the Play / App Store
listing.

| Bump | When |
|---|---|
| MAJOR | Reserved; intentionally NOT touched during Beta. First MAJOR bump (`1.0.0`) marks the public launch milestone. |
| MINOR | Feature release with user-facing scope change (e.g. push notifications land → `0.1.0` → `0.2.0`). |
| PATCH | Bugfix release with no scope change (e.g. `0.2.0` → `0.2.1`). |

Pre-1.0 caveat: while in Beta, MINOR bumps cover anything that
changes user-facing behavior. PATCH is reserved for purely
non-user-visible fixes (a server timeout adjustment, a crash fix).
Don't worry about strict semver invariants — there's no public API
contract yet.

### 3.2 `versionCode` — monotonic integer

Plain integer. **Every upload to any track requires a strictly higher
versionCode than every prior upload across every track.**

- Play rejects re-uploads of the same versionCode, even on different
  tracks. `0.1.0+2` Internal → `0.1.0+3` Closed → `0.1.0+4` Open
  is the steady-state cadence.
- TestFlight: same rule. CFBundleVersion must be monotonic per
  CFBundleShortVersionString-and-bundle-id pair.

The versionCode does NOT need to follow versionName. Both increment
independently. Examples of legal patterns:

```
0.1.0+1  → 0.1.0+2  → 0.1.0+3   (Internal iteration; same versionName)
0.1.0+3  → 0.1.0+4  → 0.1.0+5   (more internal cuts)
0.1.0+5  → 0.1.1+6                (PATCH bump for fix)
0.1.1+6  → 0.2.0+7                (MINOR bump for feature)
0.2.0+7  → 0.2.0+8                (Internal cut of 0.2.0)
```

The versionCode tracks the *build*; versionName tracks the *release*.

### 3.3 RC suffix (optional)

For release-candidate builds before promoting versionName to the
public store, use a build-number convention rather than a versionName
suffix. Play doesn't allow `-rc1` in versionName for some
configurations; the build number is universally safe.

```
0.2.0+7   → 0.2.0+8   ← rc1: Internal QA cut
0.2.0+8   → 0.2.0+9   ← rc2: regression fix
0.2.0+9   → 0.2.0+10  ← release: promoted to Closed / Open
```

Track the "this build is RC1 for 0.2.0" mapping in the release
ticket, not in the version string. Future automation can label
specific build numbers as RC vs. release.

---

## 4. Bump rules

### 4.1 Before an Internal-testing upload

| Scenario | Action |
|---|---|
| First-ever upload | Leave `version: 0.1.0+1` for the first build. Bump to `+2` for the *second* Internal upload. (Some flows prefer starting at `+2` so the first AAB matches "first uploaded" — both are fine; pick one and document.) |
| Iterating on the same versionName | `+N` → `+N+1`. Bump ONLY the build number. |
| Hotfix without scope change | `0.1.0+5` → `0.1.1+6`. Bump PATCH + build. |
| Feature added | `0.1.1+6` → `0.2.0+7`. Bump MINOR + build. |

### 4.2 Before a Closed / Open / Production upload

- versionCode **must** be higher than every Internal cut you skipped
  past. If Internal got to `+9`, your first Closed/Open/Production
  release is at least `+10`.
- versionName **should** be a clean release version (no implicit RC
  markers). If you promoted from Internal at `0.2.0+10`, the
  Closed track release is `0.2.0+10` *or* a higher build with the
  same versionName.

### 4.3 When iOS and Android diverge

Don't. The same `version:` feeds both. If you absolutely need to
ship an Android-only hotfix (e.g. a Play Console rejection that
doesn't apply to TestFlight), bump versionCode and re-ship — both
platforms will pick up the bump, and the iOS build just stays
unbuilt until the next iOS cut. Don't fork the version string per
platform — it's not worth the operational confusion.

---

## 5. Pre-bump checklist

Before changing the `version:` line:

- [ ] Confirm the current value (`grep -E '^version:' apps/mobile/pubspec.yaml`).
- [ ] Confirm the highest versionCode shipped to any track (Play
      Console → Releases overview).
- [ ] Pick the new value per §4.
- [ ] Update `pubspec.yaml`.
- [ ] Commit: `chore(mobile): bump version to X.Y.Z+N`.
- [ ] `flutter pub get` to refresh build artifacts.
- [ ] `flutter analyze` + `flutter test` baseline check.
- [ ] `flutter build appbundle --release --dart-define=...` rebuilds
      with the new code.
- [ ] Validate the AAB carries the new versionCode (Play Console
      will show it on upload; locally, `keytool -printcert -jarfile`
      doesn't show versionCode but Play does post-upload).

---

## 6. Rollback warnings

Versioning is **monotonic only**. There is no "revert to
versionCode N-1" path on Play or TestFlight. Once a build is shipped,
the only forward motion is a higher versionCode.

If a release has a serious bug:

1. **Don't** try to "republish" a lower versionCode. Play / TestFlight
   will reject.
2. **Do** bump versionCode (and versionName if it's a fix worth
   labeling, e.g. `0.2.0 → 0.2.1`).
3. Build the hotfix AAB / IPA from the fix commit.
4. Upload to the same track. Play / TestFlight will supersede the
   broken build.
5. (Play only) On the broken release in Play Console, **halt rollout**
   if it hasn't fully propagated yet — limits the bad-build install
   blast radius while the hotfix builds.

### 6.1 Bad versionCode (skipped a beat)

If you upload `0.1.0+9` to Internal by mistake when you meant
`0.1.0+5`, you cannot recover the `+5`–`+8` range. Plan the next
Internal cut at `0.1.0+10` — the lost build numbers are gone forever.
This is rare enough that the alternative — soft-tracking versionCode
locally — isn't worth the operational complexity.

### 6.2 Removed feature regressed the build

Same posture as a bug. Bump versionCode, ship the fix. Removing the
feature in a higher versionCode is the only forward path.

### 6.3 Wrong artifact uploaded

If you accidentally upload an AAB built against the wrong API
environment (`API_BASE_URL=localhost` instead of staging, say),
treat it as a "bad release":

1. Halt rollout on Play Console.
2. Rebuild with the correct `--dart-define=API_BASE_URL=...`.
3. Bump versionCode.
4. Re-upload.

There is no "fix-in-place" — every AAB is an immutable artifact tied
to its versionCode.

---

## 7. Reference: where the values land

| Field | File | How it's set |
|---|---|---|
| `version` | `apps/mobile/pubspec.yaml` | Hand-edited, single source of truth |
| `versionName` (Android) | `apps/mobile/android/app/build.gradle.kts:55` | `versionName = flutter.versionName` — derived |
| `versionCode` (Android) | `apps/mobile/android/app/build.gradle.kts:56` | `versionCode = flutter.versionCode` — derived |
| `CFBundleShortVersionString` (iOS) | `apps/mobile/ios/Runner/Info.plist` *(once iOS scaffold exists)* | `$(FLUTTER_BUILD_NAME)` — derived |
| `CFBundleVersion` (iOS) | `apps/mobile/ios/Runner/Info.plist` *(once iOS scaffold exists)* | `$(FLUTTER_BUILD_NUMBER)` — derived |

Verify the wiring stays single-source whenever the iOS scaffold
lands. Hardcoded values in `Info.plist` (e.g. `<string>1.0</string>`
instead of `<string>$(FLUTTER_BUILD_NAME)</string>`) is the most
common drift source.

---

## 8. Migration / first-upload note

Today's `version: 0.1.0+1` is the right starting point. Recommended
posture for the first three Internal uploads:

```
0.1.0+1  — current; first AAB if you choose "first upload uses +1"
0.1.0+2  — first post-iteration cut
0.1.0+3  — second iteration
…
0.1.1+N  — first PATCH (likely a Beta hotfix)
0.2.0+M  — first MINOR (a feature added post-Beta)
1.0.0+P  — public launch
```

Some operators prefer to leave `0.1.0+1` *unshipped* and start
Internal uploads at `0.1.0+2`, reserving `+1` as a "did this even
build" marker. Either pattern is fine — document it in the release
ticket so future operators understand the offset.
