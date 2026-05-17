# PRISM Club — Privacy & Data Inventory (Draft)

> **STATUS: DRAFT.** This document is an engineering inventory of every
> personal-data field PRISM Club currently touches, intended as raw
> input for a privacy policy + Play Data Safety form + App Privacy
> form. It is **not** a privacy policy, **not** legal advice, and
> **not** an attestation of regulatory compliance. Any user-facing
> publication MUST be reviewed by legal + product before posting.
> Drafted: 2026-05-18. Re-verify against the codebase before each
> store submission.

Pairs with:

- [ANALYTICS.md](ANALYTICS.md) — first-party event taxonomy + scrub
  rules (the source of truth for analytics privacy).
- [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) §6 — the
  go/no-go checklist this inventory feeds.
- [PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md) §7 + §8 — the
  privacy-policy + Data Safety form gates.

---

## 1. Scope

What this document covers:

- Every field PRISM Club's API persists, captures, or transmits that
  could relate to a natural person.
- Every third-party data processor the deployment talks to (today:
  none in the production code path; some envelope possibilities are
  noted as deferred / configurable).
- The lifecycle of each field: collected → stored → retained →
  controlled.

What this document does NOT cover:

- Operational logs (request-id, error logs) — these are operator
  responsibility per deployment.
- Future provider wiring (push, email, warehouse export, CDN). When
  those land, this inventory must be revised.
- Jurisdictional compliance specifics (GDPR / CCPA / Korean PIPA
  Article-X). Legal counsel will translate this inventory into the
  required disclosures per jurisdiction.

---

## 2. Data collected (today)

Cross-referenced against the schema in `prisma/schema.prisma` and the
analytics taxonomy in [ANALYTICS.md](ANALYTICS.md) §2.

### 2.1 Account / identity

| Field | Source | Where stored | Notes |
|---|---|---|---|
| User UUID | Server-generated on first auth | `users.id` | Internal identifier; never user-controlled. |
| Nickname | User-chosen at signup (today: pre-seeded persona) | `profiles.nickname` | Public; displayed on every post / reply / profile. Unique constraint. |
| Avatar URL | Not collected at Beta | `profiles.avatar_url` (nullable, NULL today) | Field exists for future avatar upload; today is always NULL. |
| Bio | User-edited optional text (max 500 chars) | `profiles.bio` (nullable) | Public on the profile page. |
| Region | User-edited optional text (max 50 chars) | `profiles.region` (nullable) | Free-form string (e.g. "서울"); not validated against any external taxonomy. |
| Interests | User-edited optional array (max 10 items, max 30 chars each) | `profiles.interests` (JSON array, default `[]`) | Lowercase-normalized, deduplicated. Public on the profile page. |
| Role(s) | Operator-assigned (seed or admin action) | `user_roles` (M:N to users) | MEMBER (default), VERIFIED_PLANNER, CURATOR, MODERATOR, ADMIN. Surfaced as a chip on the profile page. |
| JWT (session token) | Server-issued at `/v1/auth/login` | Client-side only (Android Keystore via `flutter_secure_storage`; web SharedPreferences fallback) | HS256-signed, 7-day expiry. Stateless — server does NOT store sessions. No refresh token. |

**Email / phone / legal name: NOT collected.** Authentication is
passwordless at Beta (any seeded user id signs in). When email login
lands (see [NEXT_BACKLOG.md](NEXT_BACKLOG.md) §1), this inventory and
the privacy policy MUST be updated.

### 2.2 User-generated content (UGC)

Public-by-default; visible to anyone who can see the parent space /
room / post per the M4 access-control rules.

| Field | Source | Where stored | Notes |
|---|---|---|---|
| Post body | User text input | `posts.body` (text) | Plain text. No HTML / rich text. Indexed for search (ILIKE). |
| Post recruitment fields | User-structured input (planner space only) | `posts.recruitment_fields` (JSONB) | Role / schedule / location / compensation / capacity / application method / status. |
| Reply body | User text input | `replies.body` (text) | Plain text. Max depth 2 enforced at service layer. |
| Knowledge contribution | User text input (proposed edit / new block) | `knowledge_contributions.proposed_*` (text) | Curated by CURATOR roles. Audit snapshot kept on the contribution row. |
| Reaction (like) | User toggle | `reactions` (M:N user × post) | One row per (user, post) — toggle on/off. |
| Save / bookmark | User toggle | `saved_items` (user × target) | Private to the user; not surfaced on the profile. |
| Follow / room-follow | User toggle | `room_follows` (user × room) | Private to the user. |
| User-follow | User toggle | `user_follows` (follower × followed) | Public — surfaced as follower/following counts on the profile. |
| Report (moderation) | User-submitted | `reports` (with `reason`, `details`, `target_type`, `target_id`) | Private to the reporter + moderators. The reporter's identity is NEVER shown to the target user. |

### 2.3 Media

| Field | Source | Where stored | Notes |
|---|---|---|---|
| Image upload | User-picked from device gallery | `media_assets` row + binary at `MEDIA_STORAGE_MODE` location | jpg/png/webp/gif only, ≤5 MB. Local mode: `apps/api/uploads/`. S3 mode: configured bucket. |
| Image MIME type | Derived | `media_assets.mime_type` | One of `image/jpeg`, `image/png`, `image/webp`, `image/gif`. |
| Image size | Derived | `media_assets.size_bytes` | Used for storage accounting; not user-visible. |

**Image EXIF metadata is NOT stripped** today. If user images carry
GPS / camera metadata, that metadata is preserved in storage. This
should be flagged for the privacy policy + addressed before
Production (auto-strip on upload is a simple add).

### 2.4 First-party analytics events

Captured server-side per [ANALYTICS.md](ANALYTICS.md) — eleven event
types today. Privacy invariants enforced in code via
`AnalyticsService.scrubPayload()`:

- **Forbidden keys** (substring match, dropped silently): `body`,
  `message`, `content`, `email`, `phone`, `password`, `token`,
  `access_token`.
- **String values** truncated to 120 chars with `…` suffix.
- **Nested objects** dropped.
- **No user-generated content** in any payload — ids + counts only.
- **No IP / user-agent** captured.
- Actor id is the authenticated user UUID; null for any future
  unauthenticated event (none today).

| Event | Payload keys |
|---|---|
| `AUTH_LOGIN` | `roles_count` |
| `POST_CREATED` | `post_id`, `room_slug`, `post_type`, `attachment_count` |
| `REPLY_CREATED` | `reply_id`, `post_id`, `is_nested` |
| `ROOM_FOLLOWED` / `ROOM_UNFOLLOWED` | `room_id`, `room_slug` |
| `ITEM_SAVED` / `ITEM_UNSAVED` | `target_type`, `target_id` |
| `NOTIFICATION_READ` | `notification_id`, `notif_type` |
| `REPORT_CREATED` | `report_id`, `target_type`, `target_id` |
| `MEDIA_UPLOADED` | `media_id`, `mime_type`, `size_bytes`, `storage_mode` |
| `EVENT_DETAIL_VIEWED` | `event_card_id`, `post_count`, `room_count` |

Full taxonomy authority: [ANALYTICS.md](ANALYTICS.md) §2.

### 2.5 NOT collected

Explicit non-collection list (these are the questions Play / App
Store Data Safety forms ask):

| Category | Status | Why |
|---|---|---|
| Email address | NOT collected | Auth is passwordless at Beta. Becomes relevant when email login lands. |
| Phone number | NOT collected | No SMS path planned for Beta. |
| Legal name / address / DOB | NOT collected | No identity verification flow. |
| Race / ethnicity / political views / religion / sexual orientation | NOT collected | None requested in any form. |
| Health / fitness data | NOT collected | Out of product scope. |
| Financial info (payment card, bank, transactions) | NOT collected | No monetization at Beta. |
| Precise location (GPS) | NOT collected | No location-aware feature. |
| Approximate location (IP-derived) | NOT collected | API does not store request IP. |
| Device identifier (advertising id / Android id / IDFA) | NOT collected | No advertising SDK. |
| IP address | NOT collected | API does not store request IP (operator-level logs are out of scope). |
| User agent / device model | NOT collected | API does not store request UA. |
| Search queries | NOT persisted | Search is computed on each request; queries are not stored. |
| Crash / diagnostic logs | NOT collected client-side | No Crashlytics / Sentry wired today. |
| Audio / video / voice recordings | NOT collected | No mic / camera capture. |
| Contacts / calendar / SMS / call logs | NOT collected | No permission requested. |

---

## 3. Purpose of collection

Each field group has a single, narrow purpose. We do NOT collect data
for advertising, profiling, or third-party sharing.

| Purpose | Fields used | Why |
|---|---|---|
| **Authentication** | User UUID, JWT | Sign in / authorize subsequent API calls. |
| **App functionality** | Nickname, avatar URL, bio, region, interests, role(s), follow / save / reactions, user-generated post / reply / contribution / report content, image uploads | Power the community surfaces the user is here for. |
| **Moderation** | Report rows, moderation audit log | Operate the community; enforce content rules. |
| **First-party analytics** | Eleven event types per §2.4 | Understand product usage in aggregate. No per-user advertising / targeting. |
| **Operational health** | Server-side error logs (not in this inventory; operator concern) | Keep the service running. Operator should configure log shipping with explicit retention. |

---

## 4. Storage + retention

### 4.1 Where data lives

| Storage | What | Where |
|---|---|---|
| PostgreSQL (primary DB) | All structured data (users, profiles, posts, replies, contributions, reactions, follows, saves, notifications, reports, audit logs, analytics events) | Operator-controlled host (Beta: managed Postgres; dev: Docker container on port 5433) |
| Local filesystem (`MEDIA_STORAGE_MODE=local`) | Image binaries | `UPLOADS_DIR` (default `apps/api/uploads/`) on the API host |
| S3-compatible (`MEDIA_STORAGE_MODE=s3`) | Image binaries | Configured bucket (AWS S3, Cloudflare R2, MinIO) |
| Client device — Android Keystore | JWT session token | Per-app encrypted store, wiped on uninstall or app data clear |
| Client device — iOS Keychain | JWT session token | Per-app encrypted store, wiped on uninstall or "Settings → Reset → Erase All Content" |
| Client device — Web SharedPreferences | JWT session token (fallback for web only) | Browser-local storage; not encrypted at rest. |

### 4.2 Retention

| Data | Default retention | Notes |
|---|---|---|
| Account row | Indefinite (until user deletes) | Account deletion flow is deferred — see §5 below. |
| Posts / replies / contributions | Indefinite, soft-delete via `status = DELETED` | Deleted rows excluded from every read surface via `status: { notIn: ['DELETED', 'HIDDEN'] }`. |
| Media binaries | Indefinite | No automated cleanup. Operator may prune orphaned uploads. |
| Notifications | Indefinite (until user clears) | "Mark all read" flips status; rows are not auto-purged. |
| Reports + moderation audit | Indefinite | Compliance / safety audit trail. |
| Analytics events | Indefinite by default | `analytics_events` table grows monotonically. Suggested pruner: `DELETE FROM analytics_events WHERE created_at < NOW() - INTERVAL '90 days'` ([ANALYTICS.md](ANALYTICS.md) §6). |
| Server-side logs | Operator-configured | Out of scope for this doc; operator should set retention per their log-shipping policy. |
| Client JWT | 7 days (HS256 exp claim) | Cleared on logout or app data clear. |

**Retention is the largest open question for this inventory.** Beta
posture is "keep everything." Production posture should define an
account-deletion flow that propagates to UGC + media + analytics
(per-user). This is on the backlog ([NEXT_BACKLOG.md](NEXT_BACKLOG.md))
and MUST be resolved before promoting beyond Internal testing on
either store.

---

## 5. User controls

What the user can do today, what's deferred.

### 5.1 Available today

- **Edit profile** — bio / region / interests via the edit-profile
  bottom sheet on the user's own profile.
- **Logout** — wipes the local JWT (Android Keystore / iOS Keychain /
  Web SharedPreferences). The JWT is stateless, so this is
  effectively immediate session termination from the device.
- **Delete a post / reply** — soft-delete from the author menu (sets
  `status = DELETED`).
- **Unfollow / unsave / unfollow user** — toggles via the
  corresponding UI affordance.
- **Report content** — submit a moderation report; the report flow
  is private and the reporter identity is never disclosed to the
  target.

### 5.2 NOT available — deferred

- **Account deletion** — no UI flow; no API endpoint. **MUST** land
  before Production (Play Data Safety form asks; Apple App Privacy
  also requires it for many app categories).
- **Data export (DSAR-style)** — no path today to export "all my
  data." Deferred; operator-driven export is possible via direct DB
  query as a one-off.
- **Email / push opt-out** — no email / push delivered today
  (`NOTIFICATION_DELIVERY_MODE=noop` is the default; `email` and
  `push` modes are boundary stubs).
- **Nickname rename** — intentionally NOT supported; renames have
  cache / display implications across existing posts that aren't
  worth the complexity at Beta.
- **Avatar upload** — field exists, no UI yet.
- **Block / mute another user** — deferred.

The deferred list is the most important section to surface to legal
+ product before publishing a privacy policy. Several items (account
deletion, email opt-out) are increasingly considered table stakes
for any consumer app.

---

## 6. Third-party processors

Today, the **production code path** does NOT send PRISM Club user
data to any third-party processor. The deployment touches:

| Service | Role | Status | Data shared |
|---|---|---|---|
| Operator-controlled Postgres | Primary DB | In production code path | All structured data — operator's data plane. Not a third party from the user's view if hosted by the operator; treated as third party if a managed-DB vendor (e.g. AWS RDS, Supabase, Neon) is used — disclose accordingly. |
| Operator-controlled S3 bucket (when `MEDIA_STORAGE_MODE=s3`) | Image storage | In production code path when configured | Image binaries. Disclose the cloud vendor (AWS / Cloudflare / etc.). |
| PRISM EVENT API (when `EVENTS_CLIENT_MODE=prism`) | External event metadata fetch | In production code path when configured | **No PRISM Club user data sent.** Outbound calls fetch event listings only — no `actor_id`, no nickname, no IP, no payload identifying the requesting user. Reviewed at `apps/api/src/modules/events-client/prism-events.client.ts`. |
| Email provider (future) | Notification delivery | Boundary stub only — NOT in code path | Will share recipient email + notification copy. Re-inventory when wired. |
| Push provider (future, e.g. Firebase / APNs) | Push delivery | Boundary stub only — NOT in code path | Will share device push tokens + notification copy. Re-inventory when wired. |
| Crash reporter (future) | Diagnostic | NOT wired | If added: re-inventory; default-on Crashlytics sends bundle id, OS version, stack traces — clarify if any user identifiers are attached. |
| Analytics warehouse export (future) | Aggregate analytics | NOT wired | Re-inventory when exporter ships. |

This list MUST be re-verified before each store submission. If the
operator chooses a managed-DB host (RDS / Supabase / Neon / Aiven),
disclose that vendor in the privacy policy.

---

## 7. Network transit + at-rest encryption

- **Mobile client ↔ API:** HTTPS over public networks. The Flutter
  client speaks HTTPS to staging / production. iOS App Transport
  Security defaults block plain HTTP — no exception added.
- **Web client ↔ API:** Same — HTTPS over public networks.
- **API ↔ Postgres:** TLS to the DB is operator-configured. The
  default `DATABASE_URL` shape supports `sslmode=require`. Verify
  before Production.
- **API ↔ S3 (when configured):** TLS by default in all AWS / R2 /
  MinIO clients. The S3 SDK enforces HTTPS endpoints.
- **At rest (DB):** Encryption at rest is operator / managed-DB
  responsibility. Disclose in the privacy policy what the operator
  has configured.
- **At rest (S3):** S3 server-side encryption (AES-256 or KMS) is a
  bucket-level setting; operator-configured.
- **Client device:** JWT in Android Keystore / iOS Keychain is OS-
  encrypted at rest. Web SharedPreferences fallback is NOT
  encrypted — disclose that web sessions are best-effort only.

---

## 8. Play Data Safety form — draft answers

Cross-checked against the per-field disclosures in §2.

### 8.1 Top-level questions

| Question | Draft answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** — HTTPS API; operator-configured DB TLS |
| Do you provide a way for users to request that their data is deleted? | **Yes (support-email path acceptable for Internal track)** — Production posture requires an in-app account-deletion flow (see §5.2). DRAFT — confirm before Production. |
| Do you adhere to Play Families Policy? | **N/A** — not a children's app |
| Has your app been independently reviewed against a global security standard? | **No** |

### 8.2 Data type matrix

| Category | Collected? | Shared with third parties? | Optional? | Purpose |
|---|---|---|---|---|
| Personal info → Name | **Yes** (nickname only — user-chosen, not legal name) | **No** | **No** (required for the account) | App functionality (display on posts / profile) |
| Personal info → Email | **No** | n/a | n/a | n/a |
| Personal info → User ID | **Yes** (server-generated UUID) | **No** | **No** | App functionality + first-party analytics |
| Personal info → Address / phone / race / political views / sexual orientation / religion | **No** | n/a | n/a | n/a |
| Financial info | **No** | n/a | n/a | n/a |
| Health & fitness | **No** | n/a | n/a | n/a |
| Messages → Emails / SMS / MMS | **No** | n/a | n/a | n/a |
| Messages → Other in-app messages (posts / replies / contributions / reports) | **Yes** | **No** | **No** (the user provides this content by participating; some surfaces like contributions / reports are optional) | App functionality |
| Photos and videos → Photos | **Yes** (user-uploaded post attachments) | **No** | **Yes** (only when the user picks one) | App functionality |
| Audio / Files & docs / Calendar / Contacts / Location / SMS / Call logs | **No** | n/a | n/a | n/a |
| App activity → App interactions | **Yes** (eleven first-party event types — body / message / email / token scrubbed) | **No** | **No** | Analytics |
| App activity → In-app search history | **No** (queries not persisted) | n/a | n/a | n/a |
| App activity → Installed apps / other user-generated content | **No** | n/a | n/a | n/a |
| Web browsing | **No** | n/a | n/a | n/a |
| App info & performance → Crash / diagnostic / other performance | **No** | n/a | n/a | n/a |
| Device or other IDs → Device or other identifiers | **No** | n/a | n/a | n/a |

### 8.3 Security practices

- Encrypted in transit: **Yes**
- Users can request data deletion: **Yes** (path defined in privacy
  policy; in-app flow required before Production — see §5.2)
- Committed to Play Families Policy: **N/A**

---

## 9. Apple App Privacy — draft answers

Apple's form (App Store Connect → App Privacy) groups slightly
differently from Play's. Cross-walk:

| Apple category | PRISM Club status |
|---|---|
| Contact Info → Email Address | NOT collected |
| Contact Info → Phone Number | NOT collected |
| Contact Info → Physical Address | NOT collected |
| Contact Info → Name | "Nickname" — user-chosen; collected, linked to user, used for App Functionality, NOT used for Tracking |
| Health & Fitness | NOT collected |
| Financial Info | NOT collected |
| Location → Precise Location | NOT collected |
| Location → Coarse Location | NOT collected |
| Sensitive Info | NOT collected |
| Contacts | NOT collected |
| User Content → Emails or Text Messages | NOT collected |
| User Content → Photos or Videos | Collected (user-uploaded), linked to user, used for App Functionality |
| User Content → Audio Data | NOT collected |
| User Content → Customer Support | NOT collected |
| User Content → Other User Content | Collected (posts, replies, profile bio, contributions, reports), linked to user, used for App Functionality |
| Browsing History | NOT collected |
| Search History | NOT persisted |
| Identifiers → User ID | Collected (UUID), linked to user, used for App Functionality + Analytics |
| Identifiers → Device ID | NOT collected |
| Purchases | NOT collected |
| Usage Data → Product Interaction | Collected (first-party event taxonomy), linked to user, used for Analytics |
| Usage Data → Advertising Data | NOT collected |
| Usage Data → Other Usage Data | NOT collected |
| Diagnostics → Crash / Performance / Other | NOT collected |
| Other Data | NOT collected |

**Tracking declaration:** "Data is **not** used to track you." PRISM
Club does not link the collected data to data collected by third-
party apps / websites for advertising or measurement.

---

## 10. Privacy policy outline

Suggested structure for the public privacy policy, derived from §1–9.
Counsel will translate and adapt for jurisdiction.

1. **Who we are.** PRISM Club is operated by <legal entity>.
   Contact: <support email>.
2. **What we collect.** §2 of this document, summarized in user-
   friendly language.
3. **Why we collect it.** §3.
4. **How long we keep it.** §4 — with the caveat that Beta
   retention is "indefinite" and Production retention will be
   updated.
5. **Who we share it with.** §6. Default = "we don't share with
   third parties for advertising or analytics."
6. **Your controls.** §5.1. Disclose §5.2 deferrals honestly:
   "Account deletion is currently handled by emailing support;
   self-service deletion is in development."
7. **Security.** §7.
8. **Children.** Not a children's app; no users under <legal
   age> by policy. Decide age floor with counsel (likely 13+
   under COPPA, 14+ under Korean PIPA; product audience is
   adults).
9. **International transfers.** Disclose the operator's hosting
   region(s).
10. **Updates to this policy.** Versioned with date.
11. **Contact.** Support email, response SLA.

---

## 11. Re-verification checklist (for future release prep)

Before each store submission, walk this checklist to catch drift
between code and disclosed inventory.

- [ ] `git log --since=<prior-submission-date> -- prisma/` shows no
      new tables / columns that need inventorying.
- [ ] `git log --since=<prior-submission-date> -- apps/api/src/modules/analytics/`
      shows no new event types (or §2.4 is updated).
- [ ] `apps/api/src/modules/analytics/analytics.service.ts` `EventType`
      union still matches the §2.4 table.
- [ ] No new third-party HTTP outbound from the API (`grep -RIn 'http' apps/api/src/`
      reviewed for new clients).
- [ ] Image upload still strips no EXIF, or the EXIF-strip ships
      and §2.3 is updated.
- [ ] Account-deletion flow status is honestly reflected in §5 /
      §8.1.
- [ ] Third-party processors list (§6) matches the actual deployed
      env (managed-DB vendor disclosed, S3 vendor disclosed,
      `EVENTS_CLIENT_MODE`, `NOTIFICATION_DELIVERY_MODE`,
      `MEDIA_STORAGE_MODE`).
- [ ] Privacy policy URL on the public site matches what the
      store listing references.

---

## 12. Sign-off (operator + legal)

```
Privacy inventory revision : <YYYY-MM-DD>
Drafted by (engineering)    : <name>
Reviewed by (product)       : <name / date>
Reviewed by (legal)         : <name / date / firm>
Privacy policy URL          : <link>
Privacy policy revision     : <date — matches the URL's footer date>
Play Data Safety updated    : <date>
App Store Privacy updated   : <date>

Outstanding follow-ups      :
  [ ] Account deletion flow (self-service)
  [ ] EXIF-strip on image upload
  [ ] Retention policy for analytics_events
  [ ] Managed-DB / S3 vendor disclosure
  [ ] Privacy policy KO + EN copies hosted
```

Mark **APPROVED** only when every item in this inventory has a
matching disclosure in the public privacy policy + store forms.
