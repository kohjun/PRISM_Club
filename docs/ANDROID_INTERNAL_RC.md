# PRISM Club — Android Internal RC Checklist

The single-page, pre-upload checklist for cutting an **Internal
testing** release candidate (RC) on Google Play. Use this as the
last gate before the operator presses **Start rollout** in Play
Console. Every item is binary — PASS or FAIL. If anything fails,
hold the upload.

Pairs with:

- [PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md) — the
  comprehensive Play Console walkthrough this checklist tightens
  into a pre-flight.
- [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) — the
  full Beta release checklist; this RC checklist is a subset
  targeted at Android Internal testing.
- [MOBILE_VERSIONING.md](MOBILE_VERSIONING.md) — versionCode / Name
  bump rules.
- [ANDROID_RELEASE_DRY_RUN.md](ANDROID_RELEASE_DRY_RUN.md) — what
  works today; signing dry-run posture.
- [APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md) — icon + splash
  pipeline.
- [PRIVACY_DATA_INVENTORY.md](PRIVACY_DATA_INVENTORY.md) — DRAFT
  inventory feeding Play Data Safety.

---

## 1. Commit baseline + branch posture

The artifact must come from a clean, tagged commit on `main` so
post-upload bisection is possible.

- [ ] `git status` is clean — no uncommitted edits.
- [ ] `git log -1 --format='%H %s'` matches what the release ticket
      claims is being shipped.
- [ ] Current branch is `main` (or the release branch agreed in the
      release ticket).
- [ ] `git tag` plan: tag the RC commit AFTER successful upload as
      `mobile-rc-vX.Y.Z-buildN` (e.g.
      `mobile-rc-v0.1.0-build2`). Tag is recorded in the release
      ticket.

Today's commit baseline (this checklist's reference point):

```
$ git log -1 --format='%H %s'
5df6eef docs: add privacy data inventory draft
```

This is a docs-only commit. The first real RC would be cut from a
slightly later commit after the operator has populated
`key.properties` and verified the assets per §4.

---

## 2. Versioning

Cross-reference [MOBILE_VERSIONING.md](MOBILE_VERSIONING.md) for the
bump rules.

- [ ] `apps/mobile/pubspec.yaml` `version:` line:
      ```
      version: <X.Y.Z+N>
      ```
- [ ] `+N` is **strictly higher** than every previously uploaded
      versionCode (any track). Verify against Play Console →
      Releases overview.
- [ ] `versionName` (the part before `+`) reflects the intent of
      this RC — keep stable for Internal iteration; bump PATCH for
      hotfixes; bump MINOR for feature changes.
- [ ] If this is RC-N for a versionName, record the
      (versionName, build N, RC label) mapping in the release
      ticket.

Today the pubspec is `version: 0.1.0+1`. The first Internal upload
would bump to `0.1.0+2`.

---

## 3. Required tests + analyzer

Run before building the release AAB. **All must pass.**

```bash
# From repo root
cd apps/mobile
flutter pub get
flutter analyze        # info-only output is OK; no warnings / errors
flutter test           # all widget tests pass
```

- [ ] `flutter analyze` → no errors, no warnings. Info-level lints
      acceptable.
- [ ] `flutter test` → all tests green (53+ widget tests today).
- [ ] Backend tests run separately if API has changed:
      `npm run api:test && npm run api:test:e2e` from the repo
      root.

Reference: at `5df6eef` the verification output is:

```
$ flutter analyze
6 issues found.  (all info-level — no errors, no warnings)

$ flutter test
74 widget tests passed
```

---

## 4. Pre-build asset / signing gates

Each MUST be true before invoking `flutter build appbundle`.

### 4.1 Signing

- [ ] `apps/mobile/android/key.properties` exists on the build host
      and is populated from the vault.
- [ ] The keystore file referenced by `storeFile` is readable.
- [ ] Operator has access to the keystore passwords (no "we'll find
      them later" — confirm BEFORE building).

### 4.2 Branding

- [ ] Launcher icon is the brand mark, not the default Flutter "F".
      Verify against [APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md)
      §8 status snapshot — every mipmap density should be the brand
      icon, adaptive icon XML should exist, splash background
      should be the brand color.
- [ ] App label resolves to "PRISM Club" via
      `apps/mobile/android/app/src/main/res/values/strings.xml`.

> **Today's state (commit `5df6eef`):** the launcher icon is still
> the Flutter "F" placeholder. This RC checklist would FAIL §4.2
> until the asset pipeline runs against real source files. The
> first Internal upload must come AFTER §4.2 is resolved — see
> [APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md).

### 4.3 API URL

- [ ] The `--dart-define=API_BASE_URL=...` flag is set to the
      target API for this RC (staging for first Internal cut;
      production once cut over).
- [ ] The URL is HTTPS (Apple ATS + Play Data Safety both expect
      this).

---

## 5. Build commands

The exact commands the operator runs from `apps/mobile/`:

```bash
# Final, release-shaped AAB build
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.staging.<your-domain>/v1
```

Watch the Gradle output for this warning — if it appears, STOP and
re-check §4.1:

```
[prism-club] android/key.properties not found — release build will
be DEBUG-SIGNED and rejected by Play Console. ...
```

A debug-signed AAB is rejected at upload time. Do NOT proceed past
this warning.

Optional companion build (sideload AAB → APK for ad-hoc QA):

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.staging.<your-domain>/v1
```

---

## 6. Post-build artifact verification

Run these checks against the freshly built AAB before uploading.

### 6.1 AAB exists + size sanity

- [ ] File at expected path:
      `apps/mobile/build/app/outputs/bundle/release/app-release.aab`
- [ ] Size in the 35–55 MB range. Current baseline at commit
      `5df6eef`: **42.2 MB** (matches the c352973 baseline
      tracked in [ANDROID_RELEASE_DRY_RUN.md](ANDROID_RELEASE_DRY_RUN.md) §7).
- [ ] If size jumped by >20% release-to-release, investigate before
      uploading — likely a binary asset was committed in error.

Verify:

```bash
ls -lh apps/mobile/build/app/outputs/bundle/release/app-release.aab
```

### 6.2 Signing certificate fingerprint

- [ ] `keytool -list -printcert -jarfile <path>/app-release.aab`
      shows the operator's **upload-key** certificate fingerprint,
      not the debug-keystore one (`CN=Android Debug, O=Android,
      C=US`).
- [ ] Fingerprint matches what Play Console has registered for the
      app (Play Console → Setup → App integrity → Upload key
      certificate).

```bash
keytool -list -printcert -jarfile \
  apps/mobile/build/app/outputs/bundle/release/app-release.aab
```

### 6.3 Manifest permissions

Build a release APK alongside the AAB (the AAB unpacking is a bit
more work; APK is easier) and verify the merged manifest carries
only INTERNET:

```bash
unzip -p apps/mobile/build/app/outputs/flutter-apk/app-release.apk \
  AndroidManifest.xml | grep -aE "uses-permission|uses-feature"
```

- [ ] Only `android.permission.INTERNET` (and any framework-injected
      `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`) appears.
- [ ] No surprise permissions auto-added by plugins.

### 6.4 No secrets in the AAB

```bash
unzip -l apps/mobile/build/app/outputs/flutter-apk/app-release.apk | grep -iE 'key|secret|env|properties'
```

- [ ] No `key.properties` packaged in the APK.
- [ ] No `.env`, `.jks`, or `.keystore` files in the bundle.
- [ ] Output should list only Flutter framework files (e.g.
      `assets/flutter_assets/...`).

---

## 7. QA evidence

Internal testing is the venue to catch issues that don't reproduce
in `flutter run`. The RC build MUST install via the Play Store opt-
in URL on ≥1 physical device before promotion.

- [ ] Build is uploaded to **Internal testing** track in Play
      Console with release notes.
- [ ] At least one tester (the operator counts) installs from the
      Play opt-in URL on a physical Android device.
- [ ] Cold launch path: launcher icon → splash → login picker →
      home feed renders within 5 seconds on LTE.
- [ ] [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md) runs green on the
      installed Internal build against the staging API.
- [ ] Image upload exercised on the physical device: pick a >2 MB
      image, post, reopen the room — thumbnail renders.
- [ ] External Reference URL exercised: tap a Reference link →
      browser opens (verifies `url_launcher` package-visibility
      queries are in the release manifest).
- [ ] Sign-out → reopen → login picker shown (session is wiped).
- [ ] Cold session restore: force-close from recents, reopen — JWT
      restored, home loads without re-auth.
- [ ] Korean glyph rendering verified on every screen (no tofu /
      missing-font squares).

Evidence captured in the release ticket: screenshots / device
model / Android version / build label.

---

## 8. Play Console paperwork

Before uploading the AAB, every dashboard section under Play
Console → Policy → App content should resolve green. Cross-walk to
[PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md) §6:

- [ ] Privacy policy URL hosted + linked in Play Console (Korean +
      English).
- [ ] App access: "All functionality available without special
      access".
- [ ] Ads: "No".
- [ ] Content rating: IARC questionnaire submitted and rating
      visible.
- [ ] Target audience: 18+ confirmed.
- [ ] Data safety: form filled per
      [PRIVACY_DATA_INVENTORY.md](PRIVACY_DATA_INVENTORY.md) §8.
      Re-verified against the latest code.
- [ ] News app / Government / Financial / Health / COVID-19: all
      "No".

---

## 9. Known limitations carried into this RC

Items the operator should disclose to internal testers via the
release notes — they are documented and accepted, not regressions:

- **No push notifications.** In-app only; users see notifications on
  next app open. ([NEXT_BACKLOG.md](NEXT_BACKLOG.md) §2)
- **Passwordless login picker.** Beta auth shows the seeded persona
  list; no real email/password yet.
  ([NEXT_BACKLOG.md](NEXT_BACKLOG.md) §1)
- **Account deletion is support-email only.** Self-service deletion
  not in-app yet. ([PRIVACY_DATA_INVENTORY.md](PRIVACY_DATA_INVENTORY.md) §5.2)
- **Image EXIF metadata not stripped on upload.** Camera GPS /
  device metadata persists in storage.
  ([PRIVACY_DATA_INVENTORY.md](PRIVACY_DATA_INVENTORY.md) §2.3)
- **No crash / diagnostic reporting.** Crashes are not captured
  beyond the OS-level Android crash log on the device.
- **Logout is client-side only.** Stateless JWT; the token is
  wiped from `flutter_secure_storage`. Server has no session
  revocation.
- **iOS scaffold absent.** Internal RC is Android-only. iOS lands
  later ([FLUTTER_NATIVE_SETUP.md](FLUTTER_NATIVE_SETUP.md) §3).

Each is acceptable for **Internal testing** but every item on this
list must be re-evaluated before promoting to Production.

---

## 10. Approval / sign-off

Once every box in §1–§9 ticks PASS, fill in the sign-off block in
the release ticket:

```
PRISM Club — Android Internal RC Sign-off
=========================================
RC label              : <e.g. 0.1.0-build2 (Internal RC1)>
Commit baseline       : <SHA>
Tag                   : mobile-rc-vX.Y.Z-buildN
Date / approver       : <YYYY-MM-DD / name>

Versioning
  versionName         : <X.Y.Z>
  versionCode         : <N>
  Source (pubspec)    : version: X.Y.Z+N

Build
  AAB path            : apps/mobile/build/app/outputs/bundle/release/app-release.aab
  AAB size            : <e.g. 42.2 MB>
  Upload key fpr      : <SHA-1 / SHA-256 from keytool -list>
  Built against URL   : <API_BASE_URL>

Tests
  flutter analyze     : PASS (info-only)
  flutter test        : PASS (<N> tests)
  Backend (if changed): PASS / N/A

Permissions
  Merged manifest     : INTERNET only
  No secrets packaged : verified (unzip -l)

QA
  Physical device     : PASS — <device model / Android version>
  BETA_QA_SCRIPT pass : <sections green>

Play Console
  Privacy policy URL  : <link>
  Data Safety filled  : <date>
  Content rating      : <rating>
  Tester opt-in URL   : <link>

Known carry-ins disclosed in release notes:
  [ ] No push
  [ ] Passwordless login
  [ ] Account deletion via support email
  [ ] EXIF not stripped
  [ ] No crash reporting
  [ ] Client-side logout only
  [ ] Android-only (no iOS)

Verdict               : APPROVED / HOLD
Outstanding items     : <list or "none">

Approver signature    : <name + date>
```

Mark **APPROVED** only when every checkbox in §1–§9 is PASS and the
release ticket has the matching evidence attached. Move to **HOLD**
→ fix → re-check.

---

## 11. Verification snapshot (today)

Captured at commit `5df6eef` (docs-only). Real RC cuts will replace
this section in the release ticket with their own measurements.

| Check | Result |
|---|---|
| `flutter analyze` | PASS — 6 info-level lints, 0 errors, 0 warnings |
| `flutter test` | PASS — 74 widget tests |
| `flutter build apk --debug` | PASS |
| `flutter build appbundle --release` | PASS — 42.2 MB (debug-signed; `key.properties` intentionally absent in repo) |
| Backend `npm run api:test` | Not run as part of this checklist commit (no API change) |
| Backend `npm run api:test:e2e` | Not run as part of this checklist commit (no API change) |
| Signing fingerprint | DEBUG (expected for the dry-run; operator must populate `key.properties` for a real RC) |
| Launcher icon | Default Flutter "F" (placeholder) — see [APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md) |

The artifact currently on disk is a **dry-run** AAB — useful for
size / pipeline verification, NOT uploadable to Play. The first
real RC follows after §4.1 + §4.2 are resolved.
