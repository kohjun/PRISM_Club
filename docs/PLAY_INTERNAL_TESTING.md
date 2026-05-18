# PRISM Club — Play Internal Testing Checklist

The exact pre-flight for the first **Internal testing** upload to
Google Play. Walks through every gate Play Console will hold the
upload at, what the engineering side has already shipped, and what
still needs operator paperwork.

> **Internal testing** is the lowest-friction Play track: up to 100
> testers per list, no review queue between uploads, share via
> opt-in URL. It is the right track for the first AAB — promotion
> to Closed → Open → Production happens later through the same
> console.

Pairs with:

- [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) — the
  full Beta go/no-go list. This doc is the Play-specific subset.
- [ANDROID_RELEASE_DRY_RUN.md](ANDROID_RELEASE_DRY_RUN.md) — what
  builds today vs. what's missing for a Play-uploadable AAB.
- [APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md) — icon + splash
  source files and regeneration.
- [PRIVACY_DATA_INVENTORY.md](PRIVACY_DATA_INVENTORY.md) — the
  data inventory that feeds the Play Data Safety form.
- [MOBILE_VERSIONING.md](MOBILE_VERSIONING.md) — versionCode /
  versionName bump policy across internal increments.

---

## 1. Prerequisites (one-time)

The accounts + access an operator must hold **before** opening the
Play Console for the first upload.

- [ ] **Google Play developer account.** $25 one-time fee. Identity
      verification can take 1–3 business days; do this first.
- [ ] **Organization developer account** (not a personal one), if
      PRISM is the publishing entity. Personal accounts are hard to
      transfer later.
- [ ] **Play Console access** for the operator (Admin role) and for
      at least one backup approver (Release manager role).
- [ ] **Custodian of the Android upload key** identified. Same
      person/team that holds the `key.properties` values in the
      vault — see [ANDROID_RELEASE_DRY_RUN.md](ANDROID_RELEASE_DRY_RUN.md) §3.
- [ ] **2FA enforced** on every Play Console account. Play upload
      keys are revocable through Play App Signing, but compromise
      of the console itself isn't.

---

## 2. Signing assets

Everything in this section lives outside the repo. The repo only
holds the **template + Gradle wiring**.

| Item | Where | Status |
|---|---|---|
| Upload keystore (`prism-club-upload.jks`) | Team password vault + build host (e.g. `~/.android/keystores/`) | ⏳ Operator generates via `keytool -genkey` ([ANDROID_RELEASE_DRY_RUN.md](ANDROID_RELEASE_DRY_RUN.md) §3.1) |
| `apps/mobile/android/key.properties` | Build host, gitignored | ⏳ Copy from `key.properties.example`, fill from vault |
| Gradle `signingConfigs.release` block | `apps/mobile/android/app/build.gradle.kts` | ✅ Shipped (commit `ca03bf4`) |
| Play App Signing enrolled | Play Console → Setup → App integrity | ⏳ Enroll on first AAB upload (Play offers it as the default) |

**Play App Signing** is the recommended posture: you upload an AAB
signed with the **upload key**, Google re-signs with the **app
signing key** they manage. Benefits:

- Upload-key compromise is recoverable (rotate via console).
- App-signing-key fingerprint stays stable for Google Pay / Smart
  Lock / Wear OS / Android Auto associations (none used yet, but
  future-proof).
- One key to manage, not two.

If Play App Signing is NOT chosen at first upload, the upload-key
fingerprint locks to the app identity — making rotation a manual
support-ticket process. Choose Play App Signing.

---

## 3. Package + application ID

The user-facing identity Play locks to the app on first upload.
**These cannot be changed after publication** without filing a new
app listing. Verify before pressing upload.

| Field | Value | Source |
|---|---|---|
| `applicationId` | `club.prism.mobile` | `apps/mobile/android/app/build.gradle.kts` `defaultConfig.applicationId` |
| `namespace` | `club.prism.mobile` | Same file, namespace block |
| App label | "PRISM Club" | `apps/mobile/android/app/src/main/res/values/strings.xml` `app_name` |
| Launcher icon | ✅ PRISM purple-gradient prism (adaptive + monochrome + 5 legacy densities) | `apps/mobile/android/app/src/main/res/{mipmap-*,drawable-*}/` — sources at `apps/mobile/assets/branding/`. Guarded by `npm run mobile:check-assets`. |

Once `club.prism.mobile` is uploaded, every future AAB MUST use the
same applicationId. Renaming requires a new app listing and loses
all install / review history.

---

## 4. versionCode + versionName policy

Both Android-side fields derive from `apps/mobile/pubspec.yaml`
`version:`. Flutter parses `<name>+<code>`:

```
version: 0.1.0+1
        ^^^^^ ^
        |     +-- versionCode (integer; MUST be monotonically increasing)
        +-- versionName (semver-ish display string)
```

Bump policy and rollback warnings live in
[MOBILE_VERSIONING.md](MOBILE_VERSIONING.md). Quick rules for Play
Internal testing:

- **Every upload to the Internal track requires a NEW `versionCode`.**
  Play rejects re-uploads of the same `versionCode`, even on the same
  track. `0.1.0+1 → 0.1.0+2 → 0.1.0+3 → …` is the steady-state.
- `versionName` only bumps when the public-facing release name
  changes (e.g. `0.1.0 → 0.1.1` after a meaningful change).
- For Internal testing iteration, keep `versionName` stable and just
  walk the `+N` build number — testers see "0.1.0 (build 7)" and
  understand it's another internal cut, not a new release.

---

## 5. Build the AAB

The artifact Play Console expects. APK is fine for ad-hoc sideload;
Play wants AAB.

Pre-flight (assumes `key.properties` is populated per §2):

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
```

All three must pass before building the release AAB.

Build:

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.staging.<your-domain>/v1
# Output: build/app/outputs/bundle/release/app-release.aab
```

Verify the artifact:

```bash
# AAB is at the expected path
ls -lh build/app/outputs/bundle/release/app-release.aab

# Size sanity — current baseline ~42 MB at commit c352973 (debug-signed).
# A release-key-signed AAB should be in the same ballpark.

# Signature is the operator's upload key, NOT the debug keystore.
keytool -list -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
# The certificate fingerprint should match the one stored in the vault.
# Debug-keystore fingerprint is the universal one (CN=Android Debug, O=Android, C=US);
# if you see that, key.properties wasn't picked up — re-check §2.
```

The Gradle warning printed when `key.properties` is missing
(see [ANDROID_RELEASE_DRY_RUN.md](ANDROID_RELEASE_DRY_RUN.md) §3.3) is
the canary — **never** upload an AAB built with that warning visible
in the log.

---

## 6. First upload flow (Play Console)

The Play Console steps for the first Internal testing release. Items
already addressed by engineering are marked ✅; operator paperwork is
⏳.

### 6.1 Create the app

- ⏳ Play Console → All apps → **Create app**.
- ⏳ App name: "PRISM Club".
- ⏳ Default language: Korean (한국어).
- ⏳ App or game: **App**.
- ⏳ Free or paid: **Free** (Beta posture; monetization deferred).
- ⏳ Declarations: confirm Play Developer Program policies + US
      export laws compliance.

### 6.2 Set up app

Mandatory dashboard sections Play surfaces before the first release:

- ⏳ **Privacy policy** — public URL drafted per §9. Required even
      for Internal testing.
- ⏳ **App access** — does the app require login / region-locked
      content / age-restricted areas? PRISM Club: **All functionality
      is available without special access** (Beta is passwordless;
      see [NEXT_BACKLOG.md](NEXT_BACKLOG.md) §1).
- ⏳ **Ads** — does the app contain ads? **No.**
- ⏳ **Content rating** — IARC questionnaire (5–10 minutes). PRISM
      Club is a community / discussion app — expected rating: Teen /
      12+ depending on the user-generated-content disclosure.
- ⏳ **Target audience** — primary age group (likely 18+; PRISM
      audience is adult event-goers).
- ⏳ **News app** — No.
- ⏳ **COVID-19 contact tracing / status** — No.
- ⏳ **Data safety** — see §8 below.
- ⏳ **Government apps** — No.
- ⏳ **Financial features** — No.
- ⏳ **Health** — No.

### 6.3 Upload the AAB to Internal testing

- ⏳ Play Console → Testing → **Internal testing** → Releases →
      **Create new release**.
- ⏳ Enable Play App Signing (first prompt) — see §2.
- ⏳ Upload `app-release.aab`.
- ⏳ Release name: defaults to versionName + versionCode (e.g.
      "0.1.0 (1)"). Override only if you want a friendlier label.
- ⏳ Release notes: 1–2 lines. For the first internal cut: "Initial
      internal testing build. PRISM Club Beta."
- ⏳ Review → Start rollout to Internal testing.

### 6.4 Tester groups

- ⏳ Play Console → Testing → Internal testing → **Testers** tab.
- ⏳ Create an email list (Google Group recommended; you can paste
      individual emails for the first round).
- ⏳ Copy the **opt-in URL** Play generates. This is what testers
      visit to join the test track.
- ⏳ Each tester must accept the invitation while signed in to the
      Google account associated with their Play Store.
- ⏳ After accepting, the app appears on their device's Play Store
      with an "Internal testing" label. First install may take up to
      a few hours to propagate even though the upload succeeded
      immediately.

Tester capacity: **100** per Internal track. Plenty for first cuts.
When PRISM expands the beta circle beyond that, promote to **Closed
testing** (still no public listing; capacity scales).

### 6.5 Store listing graphics + copy

Play Console's **Main store listing** page surfaces these assets to
testers (Internal track shows a stripped-down version, but the fields
are the same as Production — they only become required when promoting
out of Internal). Engineering has put the brand-derived assets in the
repo; the copy + screenshots remain operator paperwork.

| Asset | Spec | Status | Source |
|---|---|---|---|
| **App icon** (Play listing) | 512 × 512 PNG, 32-bit | ⏳ Operator generates from adaptive icon | Play Console auto-renders from the brand mark; or upload an explicit 512×512 export of the adaptive composite. The brand foreground + background under `apps/mobile/assets/branding/` are the source of truth. |
| **Feature graphic** | 1024 × 500 PNG / JPEG, 24-bit (no alpha) preferred | ✅ In repo | `apps/mobile/assets/branding/play_feature_graphic.png` (matches Play spec, 1024×500). Upload directly. |
| **Phone screenshots** | 1080 × 1920 portrait (or 1920 × 1080 landscape), 2–8 frames, PNG / JPEG | ⏳ Operator captures | Take from real screens once the Internal AAB is installed. Cover at minimum: login picker, home feed, a Topic Hub, a Room timeline, a Post detail. See §10 QA for the device-install flow. |
| **7-inch tablet screenshots** | 1080 × 1920 minimum on a tablet form factor | ⏳ Operator (optional for Internal, required before Production) | Take after a tablet device is allocated to QA. |
| **Short description** | ≤ 80 characters, Korean | ⏳ Operator drafts | Suggested skeleton: "주제별 토픽 허브 + 이벤트 + 레퍼런스를 모아 함께 이야기하는 PRISM 커뮤니티." Validate against PRISM brand voice before posting. |
| **Full description** | ≤ 4000 characters, Korean | ⏳ Operator drafts | Should mirror the README §1 framing (Topic Hub + 방 + 이벤트 + 레퍼런스) and call out: passwordless Beta auth, image upload limits, no third-party tracking. |
| **What's new** (release notes) | ≤ 500 characters per release | ⏳ Operator drafts per release | First Internal cut: "Initial internal testing build. PRISM Club Beta." |
| **App category** | "Social" or "Communication" | ⏳ Operator picks in console | Recommend **Social** — closer to community / forum apps Play already groups PRISM with. |
| **Tags** | up to 5 from Play's controlled vocabulary | ⏳ Operator picks | Candidates: Community, Discussion, Events, Topics. |
| **Contact email** | public-facing support email | ⏳ Operator confirms | A monitored inbox (NOT a personal address). |
| **Privacy policy URL** | public, no auth wall | ⏳ Operator confirms | See §7. |

**What "✅ In repo" means.** The asset bytes are committed under
`apps/mobile/assets/branding/`. The operator still has to upload them
to Play Console via the listing UI — there is no automated push.

**What "⏳ Operator" means.** Engineering can't pre-fill these. They
require either real product screens (screenshots), brand copy
decisions (descriptions), or organizational decisions (category,
tags, support email). Track them in the release ticket alongside the
§13 sign-off block.

`npm run mobile:check-assets` already verifies the in-repo branding
files (39 checks covering icon, adaptive layers, splash). Run it
before the Play upload to catch any drift since the brand commit.

---

## 7. Privacy policy

Mandatory for every Play upload — even Internal testing. Play will
not let the release ship without a public URL.

- [ ] Privacy policy URL drafted (e.g. `https://prism.app/privacy/club`).
- [ ] URL is publicly accessible (no auth wall, no Cloudflare
      challenge by default).
- [ ] Content matches [PRIVACY_DATA_INVENTORY.md](PRIVACY_DATA_INVENTORY.md)
      — what we collect, why, retention, controls.
- [ ] Korean-language version available (primary user language).
      English secondary is fine for the first Internal cut.

Draft the policy from
[PRIVACY_DATA_INVENTORY.md](PRIVACY_DATA_INVENTORY.md) §2 (what we
collect) + §3 (purpose) + §4 (retention). Have it reviewed by
counsel before promoting beyond Internal testing.

---

## 8. Data Safety form

Play's user-facing data disclosure. Lives under Play Console → Policy
→ **App content → Data safety**. Wrong answers here are the most
common reason a Play upload bounces.

Draft answers (cross-checked against
[ANALYTICS.md](ANALYTICS.md) §2 and
[PRIVACY_DATA_INVENTORY.md](PRIVACY_DATA_INVENTORY.md) §6):

### 8.1 Data collection + sharing

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** (UGC, account info, media we upload server-side) |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS to API; staging + production use TLS) |
| Do you provide a way for users to request that their data is deleted? | **Yes** (account deletion is part of the post-Beta roadmap — confirm before promoting to Production; for Internal testing, the support email path is acceptable) |

### 8.2 Data types collected (Play's category list)

For each category Play asks "collected?", "shared with third
parties?", "optional?", "purpose?".

| Category | Collected | Shared | Purpose |
|---|---|---|---|
| Personal info — Name | **Yes** (nickname only — user-chosen, not legal name) | **No** | App functionality (display in posts, profiles) |
| Personal info — Email | **No** (not collected yet — auth is passwordless persona picker at Beta) | n/a | n/a |
| Personal info — User ID | **Yes** (UUID assigned server-side) | **No** | App functionality, analytics (first-party) |
| Personal info — Address / phone / race / political views / sexual orientation / etc. | **No** | n/a | n/a |
| Financial info | **No** | n/a | n/a |
| Health & fitness | **No** | n/a | n/a |
| Messages — In-app messages (posts/replies) | **Yes** (user-generated public content) | **No** | App functionality |
| Photos — User-uploaded images | **Yes** (post attachments, ≤5MB) | **No** | App functionality |
| Audio / Video | **No** | n/a | n/a |
| Files & docs | **No** | n/a | n/a |
| Calendar / Contacts / Location / SMS / Call logs | **No** | n/a | n/a |
| App activity — App interactions | **Yes** (11 first-party event types from [ANALYTICS.md](ANALYTICS.md); body / message / email / token are scrubbed) | **No** | Analytics |
| App activity — Search history | **No** (queries are not persisted) | n/a | n/a |
| App info & performance — Crash / diagnostic | **No** (no Crashlytics / Sentry wired today) | n/a | n/a |
| Device or other IDs | **No** (no advertising ID / device ID / IP collected) | n/a | n/a |

### 8.3 Security practices

- Encrypted in transit: **Yes**.
- Users can request data deletion: **Yes** (path defined in privacy
  policy; for Beta = support email).
- Adheres to Play Families Policy: **N/A** (not a children's app).
- Independent security review: **No** (not yet).

Each answer in §8.2 should be cross-referenced one more time against
the source code before submission — drift between code and the form
is the most common Play rejection.

---

## 9. Permissions disclosure

Play surfaces the requested-permissions list on the store listing.
The current set (audited at commit `c352973`) is minimal:

| Permission | Auto-disclosed by Play? | Why we request |
|---|---|---|
| `INTERNET` | **No** (so common Play doesn't surface) | Every API call (Dio → REST, media upload, /v1/auth/login). |
| `<queries>` for `http` / `https` `VIEW` intents | **No** (queries aren't permissions) | `url_launcher` needs package-visibility on Android 11+ to discover a browser. |
| `<queries>` for `PROCESS_TEXT` | **No** | Flutter engine default (text processing plugin). |

**Sensitive permissions Play would surface — none requested.** The
app does NOT request `CAMERA`, `READ_MEDIA_IMAGES`,
`POST_NOTIFICATIONS`, `RECORD_AUDIO`, `ACCESS_FINE_LOCATION`, or
anything else in the sensitive list. See
[MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) §7 for the
full audit table.

Re-verify the merged manifest from the release-variant build before
upload:

```bash
unzip -p build/app/outputs/bundle/release/app-release.aab BUNDLE-METADATA/com.android.tools.build.libraries/dependencies.pb >/dev/null
# Or after extracting an AAB, inspect AndroidManifest.xml in base/manifest/
```

A simpler path — build a release APK and read its merged manifest:

```bash
flutter build apk --release --dart-define=API_BASE_URL=...
unzip -p build/app/outputs/flutter-apk/app-release.apk AndroidManifest.xml | grep -aE "uses-permission|uses-feature"
```

Only `INTERNET` (plus framework-injected
`DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` from androidx) should
appear.

---

## 10. QA before promoting from Internal

Internal testing is the right venue to catch issues that don't
reproduce in `flutter run`. Before promoting to Closed / Open /
Production:

- [ ] **Install via the opt-in URL** on a fresh device (no
      developer-mode sideload). The Play Store install path is
      different from `adb install` — exercise it.
- [ ] **Cold launch** on the installed build:
  - Launcher icon shows the brand mark (replace placeholder per
    [APP_ASSET_PIPELINE.md](APP_ASSET_PIPELINE.md) first).
  - Splash → login picker → home feed renders without a white
    flash.
- [ ] **Network paths**: login picker → /home; tap-through to a
      Topic Hub, Room, Post, EventDetail, Search, Notifications.
      Each surface should populate over real LTE (not just laptop
      Wi-Fi).
- [ ] **Cold session**: force-close the app from recents, reopen —
      JWT persisted via `flutter_secure_storage` should restore the
      session without re-prompting.
- [ ] **Sign-out** → reopen → login picker shown.
- [ ] **Image upload** on a real device: pick a >2 MB image, post,
      reopen the room — thumbnail renders.
- [ ] **External Reference link**: tap a Reference URL on a Topic
      Hub. The OS browser should open it (verifies `url_launcher`
      package-visibility queries shipped in the release manifest).
- [ ] **Backgrounding**: home button → wait 10 minutes → return.
      App should resume to the same screen; if it cold-restarts,
      that's expected on low-RAM devices and the session restore
      should still work.
- [ ] **Korean rendering**: every screen (post body, reply, profile
      bio) renders Korean glyphs without tofu or missing-font
      squares.
- [ ] **Bottom NavigationBar**: every tab (홈 / 검색 / 커뮤니티 /
      저장 / 알림) opens its primary screen.
- [ ] **Run [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md)** against the
      staging API once the Internal build is installed. That is the
      definitive cross-feature QA flow.

Use [MOBILE_QA_SCRIPT.md](MOBILE_QA_SCRIPT.md) as the faster
iteration loop during development; switch to
[BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md) on the Internal build for the
pre-promotion gate.

---

## 11. Promoting Internal → Closed / Open / Production

Promotion is a Play Console action, not a re-upload (unless the AAB
changed). Path:

- Play Console → Testing → Internal testing → Releases tab → pick a
  release → **Promote release**.
- Choose target track (Closed / Open / Production).
- Closed track lets you keep the audience controlled but increases
  the tester cap (lists or Google Groups).
- Open testing produces a Play Store listing with a "Beta" badge —
  anyone can find and install it.
- Production submits the build for Google's review (typically a few
  hours to a few days for the first submission).

**Before promoting to Production:**

- [ ] All Internal-testing QA items resolve green on at least two
      physical devices (different OEM / Android version).
- [ ] Privacy policy URL has been reviewed by counsel.
- [ ] Data Safety form re-verified against the latest code (drift
      check).
- [ ] Store listing assets complete (screenshots, feature graphic,
      full / short description, what's-new).
- [ ] [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) §14
      sign-off block filled in.

---

## 12. Rollback + unpublish

Internal testing is forgiving — testers are explicit opt-in, so
"rollback" usually means uploading a new versionCode that supersedes
the bad one.

### 12.1 Rollback a bad Internal release

1. Play Console → Testing → Internal testing → Releases → identify
   the regressed release.
2. **Halt rollout** if the release is mid-deploy (Play Internal
   propagates almost immediately, but the option exists).
3. Build the next AAB with a HIGHER `versionCode` containing the
   fix — Play does NOT support "revert to N-1" as a one-click
   action. The lowest-friction recovery is a hotfix bump.
4. Upload to the same Internal track.
5. Notify testers via the same channel they were onboarded through
   (the opt-in URL stays the same).

### 12.2 Unpublish

- Play Console → All apps → App → Setup → **Advanced settings** →
  **App availability** → toggle off.
- Removes the app from new installs for testers; existing installs
  continue to function until the user uninstalls.
- Unpublishing does NOT delete the app — the listing, history, and
  installs persist. Use **delete app** only after careful
  consideration; the action is reversible only within ~60 days.

### 12.3 What's irrecoverable

- **Lost the upload keystore** + Play App Signing NOT enabled →
  you cannot ship updates. You must file a Play support ticket to
  reset the upload key — Google requires proof of identity. This
  is exactly why §2 emphasizes Play App Signing.
- **Lost the upload keystore** + Play App Signing enabled →
  recoverable. Generate a new upload key, file a key-reset request
  via Play Console; Google approves typically within 48 hours.
- **Compromised upload keystore** → same recovery as "lost" with
  Play App Signing on. Without it, the key is the app identity and
  rotation is harder.

---

## 13. Pre-submission checklist (consolidated)

A one-page recap to skim before pressing "Start rollout":

**Engineering gates** (run from the repo, no Play Console required):

- [ ] `npm run mobile:check-assets` passes — guards adaptive icon
      `<inset>` reinjection + every density of every layered drawable
      (39 checks).
- [ ] `npm run mobile:check-signing` passes — gitignore covers
      `key.properties` / `*.jks` / `*.keystore`, the `.example`
      template is tracked, build.gradle.kts retains the
      `key.properties`-or-debug wiring (8 structural checks). Absence
      of `key.properties` on a dev machine is reported as NOTE, not
      FAIL — only the release-build host needs it.
- [ ] Upload keystore generated, vaulted, NOT in repo.
- [ ] `key.properties` populated on the **release-build host** (see
      §2). On other hosts it stays absent.
- [ ] `flutter build appbundle --release --dart-define=...` succeeds
      with NO `[prism-club] android/key.properties not found` warning.
- [ ] `keytool -list -printcert -jarfile app-release.aab` shows the
      operator's upload-key fingerprint, not the debug-keystore one.
- [ ] versionCode in `pubspec.yaml` is HIGHER than any prior upload.
- [x] Launcher icon replaced (no more Flutter "F") — shipped in
      `chore(mobile): land brand launcher icon and splash`.

**Play Console gates**:

- [ ] Feature graphic uploaded
      (`apps/mobile/assets/branding/play_feature_graphic.png`).
- [ ] At least 2 phone screenshots uploaded (captured from the
      installed Internal build).
- [ ] Short + full description in Korean.
- [ ] App category + tags selected.
- [ ] Public-facing contact email set.
- [ ] Privacy policy URL public, Korean copy ready.
- [ ] Data Safety form filled to match code.
- [ ] App content sections all green in Play Console.

**Verification + sign-off**:

- [ ] [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md) ran against the
      Internal-installed build on ≥1 physical Android device.
- [ ] [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) §14
      sign-off block filled.

If every box ticks, the upload is safe. If any one does not, hold
the upload and resolve before pressing the button.
