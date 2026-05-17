# PRISM Club — Android Release Build Dry-Run

What we can build today without any signing secrets, what's blocked,
and the exact files / env vars an operator must add to unblock the
real Play Store upload.

> **No secrets in the repo.** Every keystore / password / key alias
> lives in the operator's secret store and an operator-managed
> `android/key.properties` file (gitignored). This doc never instructs
> you to generate or commit a real keystore.

Pairs with:

- [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) §4 —
  signing checklist (Play upload key + Apple provisioning)
- [FLUTTER_APP_RELEASE_AUDIT.md](FLUTTER_APP_RELEASE_AUDIT.md) §2.3 —
  signing-related blockers identified during the readiness audit
- [FLUTTER_NATIVE_SETUP.md](FLUTTER_NATIVE_SETUP.md) §2 — daily
  Android run / build commands

---

## 1. What works today

The repo at HEAD builds both Android release artifacts on a clean
machine without any secret material. They are **debug-signed**, which
is fine for internal sideload and emulator smoke but **rejected by
Play Store** at upload time.

| Command | Output | Status |
|---|---|---|
| `flutter build apk --debug` | `build/app/outputs/flutter-apk/app-debug.apk` (~150 MB) | ✅ Builds; sideloadable on any debuggable device. |
| `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` (~52 MB) | ✅ Builds (debug-signed). Useful for internal release-shaped smoke. **Not Store-uploadable.** |
| `flutter build appbundle --release` | `build/app/outputs/bundle/release/app-release.aab` (~42 MB) | ✅ Builds (debug-signed). **Rejected by Play Console** at upload. |

Verified at commit `c352973 chore(mobile): audit android permissions`:

```
build/app/outputs/flutter-apk/app-release.apk    53,822,892 bytes
build/app/outputs/bundle/release/app-release.aab 44,202,139 bytes
```

The AAB is ~22% smaller than the APK because Play split-APK
optimizations remove unused ABIs / densities at install time.

---

## 2. Why Play rejects the dry-run AAB

`apps/mobile/android/app/build.gradle.kts` now reads
`apps/mobile/android/key.properties` at configure time:

```kotlin
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
// ... loads properties when present ...

buildTypes {
    release {
        signingConfig = if (hasReleaseKeystore) {
            signingConfigs.getByName("release")    // real upload key
        } else {
            logger.warn("[prism-club] android/key.properties not found …")
            signingConfigs.getByName("debug")      // fallback for dry-run
        }
    }
}
```

When `key.properties` is **absent** (the repo's default state), the
release build falls back to the **debug keystore** AND prints a clear
Gradle warning at configure time. Play Console:

- Rejects uploads signed with the debug keystore (well-known
  certificate fingerprint).
- Requires a stable upload key that's been registered for the app in
  Play Console.

This is intentional Play behavior — they pin the upload key to the
app's identity so a leak of the developer keystore doesn't give an
attacker a path to publish updates.

---

## 3. What's missing — exact unblocker list

To produce a Play-uploadable AAB, an operator must add **three things**
to the local environment / repo. None of them are committed.

### 3.1 Keystore file (operator-managed, NOT in git)

Generate once per app lifecycle. Keep the keystore + passwords in the
team password vault.

```bash
keytool -genkey -v \
  -keystore prism-club-upload.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias prism-club-upload
```

The keystore file (e.g. `prism-club-upload.jks`) lives outside the
repo. Recommended path: `~/.android/keystores/prism-club-upload.jks`
on the build host, mirrored in the vault.

### 3.2 `apps/mobile/android/key.properties` (gitignored)

A simple Java `.properties` file the Gradle script reads at build
time. The shape is documented in
[apps/mobile/android/key.properties.example](../apps/mobile/android/key.properties.example)
(committed placeholder; copy + fill in real values):

```properties
storeFile=/abs/path/to/prism-club-upload.jks
storePassword=<keystore password>
keyAlias=prism-club-upload
keyPassword=<key password>
```

Operator setup:

```bash
cd apps/mobile/android
cp key.properties.example key.properties
# Edit key.properties with the real values from the vault.
```

`key.properties` is gitignored by `**/android/key.properties`. The
`.example` template is whitelisted via `!**/android/key.properties.example`
so it stays in the repo. `*.jks` and `*.keystore` are also gitignored
as belt-and-suspenders so a real keystore never lands by accident.

### 3.3 `build.gradle.kts` signingConfigs.release

**Shipped** in `chore(android): add release signing template`. The
Gradle script now:

1. Reads `key.properties` at configure time if it exists.
2. Defines `signingConfigs.release` from those properties (only when
   present, so missing-file dev/CI builds don't error at configure
   time).
3. Picks the release config for `buildTypes.release` when
   `key.properties` is present; otherwise falls through to the debug
   keystore AND prints a clear, single-line Gradle warning so the
   operator sees the mismatch in the build log.

Effective state for the four common scenarios:

| Scenario | Build | Signing | Play upload |
|---|---|---|---|
| Dev laptop, no `key.properties` | succeeds | debug | rejected (warning printed) |
| Dev laptop, `key.properties` populated | succeeds | release upload key | accepted |
| CI, `key.properties` written from secrets at step time | succeeds | release upload key | accepted |
| CI, secret-store mis-wired (`key.properties` absent) | succeeds | debug | rejected (warning printed) — CI step that wires the file is at fault |

---

## 4. CI environment variables (when CI signs)

If signing happens in CI rather than on a developer laptop, encode
the four properties as CI secrets:

| Secret name | Maps to `key.properties` line |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded `.jks` file; CI decodes before build. |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword=` |
| `ANDROID_KEY_ALIAS` | `keyAlias=` |
| `ANDROID_KEY_PASSWORD` | `keyPassword=` |

CI step (sketch — not in this repo's CI yet):

```bash
echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > /tmp/keystore.jks
cat > apps/mobile/android/key.properties <<EOF
storeFile=/tmp/keystore.jks
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
keyPassword=$ANDROID_KEY_PASSWORD
EOF
cd apps/mobile && flutter build appbundle --release
```

Clear `key.properties` and the keystore from the CI workspace after
upload.

---

## 5. Play App Signing — the recommended posture

Play Console offers **App Signing by Google Play**: you upload an
AAB signed with the **upload key**, Google re-signs it with the
**app signing key** they manage. Benefits:

- Upload-key compromise is recoverable — rotate via Play Console
  without re-publishing.
- App-signing-key fingerprint stays stable for Google Pay / Smart
  Lock / Wear OS / Android Auto associations.
- You only manage one key, not two.

Recommended for PRISM Club. The first AAB upload to the Internal
test track triggers the enrollment flow.

---

## 6. Dry-run command sequence (today)

For an operator who just wants to confirm the release pipeline
works without any signing:

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.staging.<your-domain>/v1
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.staging.<your-domain>/v1
ls -lh build/app/outputs/flutter-apk/app-release.apk
ls -lh build/app/outputs/bundle/release/app-release.aab
```

Both should succeed. The APK is sideloadable for QA on a physical
device:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The AAB is **not** uploaded to Play in this state.

---

## 7. Verification matrix

Before claiming the dry-run pipeline is healthy:

| Check | Expected |
|---|---|
| `flutter build apk --release` exit code | 0 |
| `flutter build appbundle --release` exit code | 0 |
| APK file present at `build/app/outputs/flutter-apk/app-release.apk` | ✅ |
| AAB file present at `build/app/outputs/bundle/release/app-release.aab` | ✅ |
| APK size | ~50 MB (current baseline 51.3 MB at commit c352973) |
| AAB size | ~42 MB (current baseline 42.2 MB at commit c352973) |
| `jarsigner -verify -verbose build/app/outputs/flutter-apk/app-release.apk` | "jar verified" — but the certificate is the **debug** keystore |
| Sideloaded APK launches | App boots; login picker renders |

If the size jumps by >20% release-to-release, investigate before
shipping (likely a binary asset was committed that shouldn't have
been).

---

## 8. Smell tests

- [ ] `git ls-files apps/mobile/android | grep -iE 'keystore|key\.properties|\.jks'`
      returns nothing. The repo MUST stay key-free.
- [ ] The release APK does NOT include `key.properties`,
      keystores, or any other secret. `unzip -l app-release.apk |
      grep -i key` returns only Flutter framework files.
- [ ] `app-release.apk` and `app-release.aab` are in
      `apps/mobile/build/` which is gitignored — confirm a `git
      status` after building is clean.
