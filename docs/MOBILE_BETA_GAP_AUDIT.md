# PRISM Club — Mobile Beta Release Gap Audit

A single document inventorying what's between today's tree and a
Play Internal-testing upload, classified by who owns the next move.

> **Reset (current branch `feat/p1-foundation`).** Phases 1–7 +
> F-series + refactor A/B/D have landed since the prior snapshot at
> `d195ac3 docs(mobile): add physical device qa log template`
> (2026-05-20). Most of what this doc previously tagged "Decision
> deferred" (push, crash reporting, media R2, login picker) is now
> code-complete and waiting on operator-owned external setup — not
> engineering. Phase 7 added the identity-strengthening algorithm
> layer (similar-hub strip, knowledge validation badge/chain, event
> recap CTA) — see §1.7. Phase 6 Tier-3 also closed three of its four
> items (P6.10 curator portfolio, P6.11 Topic Hub Memory, P6.12 room
> roles — see §1.6); only P6.9 Scoped DM stays deferred, plus one
> P6.12 report-resolve wiring follow-up (§3).

Pairs with:

- [ARCHITECTURE_OVERVIEW.md](ARCHITECTURE_OVERVIEW.md) — canonical
  current-state architecture (Mermaid diagrams + tables).
- [MOBILE_RELEASE_CHECKLIST.md](MOBILE_RELEASE_CHECKLIST.md) —
  per-row go/no-go gate.
- [ANDROID_RELEASE_DRY_RUN.md](ANDROID_RELEASE_DRY_RUN.md) —
  signing-state forensic snapshot.
- [PLAY_INTERNAL_TESTING.md](PLAY_INTERNAL_TESTING.md) — Play
  Console workflow.

---

## 0. Status taxonomy

Every row in this audit maps to one of four statuses.

| Status | Meaning |
|---|---|
| **Implemented** | Code shipped on this branch. No external setup needed to exercise on a fresh dev install. |
| **Implemented, env/operator required** | Code shipped. Disabled or stubbed at runtime until operator wires credentials / domain / certificate. |
| **Planned** | Listed in plan, not yet implemented. |
| **Intentionally omitted** | Out of scope per `docs/00_PRISM_CLUB_BRIEF.md` + Phase 6 plan §"명시적 거부". Documented for the next person who proposes it. |

Anything previously labelled "deferred" but now code-complete moved
into one of the first two buckets.

---

## 1. Implemented (no external setup)

These all exercise end-to-end on a local dev install (`npm run dev`
+ `flutter run`). Each row references the plan id and the commit
that landed it; refer to the commit log for surrounding context.

### 1.1 Phase 1 — Production transition

| Item | Note |
|---|---|
| Email signup + login + refresh rotation (P1.1 backend) | argon2 hash, refresh family revoke on reuse, AuthGuard `typ:'access'` claim, oauth_states table for Kakao. |
| Email signup + login + refresh rotation (P1.1 mobile) | login + signup screens, `flutter_secure_storage`-backed session, 401 interceptor → `/auth/refresh`. |
| Notification preferences API (P1.2 backend) | `device_tokens` table, prefs upsert, push-delivery boundary calling firebase-admin when configured. |
| Notification preferences UI + token registration (P1.2 mobile) | settings screen + FCM token round-trip wired in `core/push/fcm_bootstrap.dart`. |
| Crashlytics bootstrap (P1.3 mobile) | `firebase_crashlytics` init, `setUserIdentifier(user.id)`, hidden ops "Throw test exception" button, ProGuard rules retained. |
| Media variants pipeline (P1.4 backend) | `media_assets` extended with `cdn_url`/`variants`/`width`/`height`, sharp produces `thumb` + `md` webp, `displayUrl` getter on the mobile DTO. |
| Share preview + access control (P1.5 backend) | `/v1/share/preview` + `/v1/share/resolve`, AccessControlService filtering, mobile `/share/:type/:id` router. |

### 1.2 Phase 2 — Topic Hub differentiation

| Item | Note |
|---|---|
| Knowledge revision history (P2.1) | `knowledge_block_revisions` table, per-block timeline screen, contribution-driven row on resolve. |
| Contribution reputation (P2.2) | `contribution_reputation` table, weighted-score formula, self-approve 403 guard, profile badge + admin leaderboard. |
| Reference source tier (P2.3) | `reference_source_rules` table, OFFICIAL/TRUSTED/COMMUNITY/UNKNOWN tier auto-classifier, mobile tier badge. |
| Topic Hub digest (P2.4) | `topic_hub_digests` table, "이번 주 변화" hub section, weekly upsert via cron. |
| Korean search upgrade (P2.5) | `pg_trgm` extension + GIN indexes, `similarity()` ranking, `SearchHitDTO.score`. |

### 1.3 Phase 3 — Event community

| Item | Note |
|---|---|
| Event RSVP (P3.1) | `event_rsvps` UNIQUE(event,user), RSVP segment control, my_rsvps screen, EVENT_UPDATED fanout on schedule change. |
| Event reminder + cron infra (P3.2) | `event_reminder_sends` table, hourly tick covering D-1/H-1/REVIEW_PROMPT, advisory lock 854_301. statusRefresh on advisory lock 854_302. |
| Event review (P3.3) | `event_reviews` table, ATTENDED-only gate, rating 1–5, report integration via `EVENT_REVIEW` target type. |
| Calendar ICS export (P3.4) | RFC 5545 builder, `share_plus` hand-off to OS calendar. |
| Event card digest (P3.5) | `event_card_digests` table, D+1 recap upsert sharing the reminder cron. |
| Recruitment applications (P3.6) | `recruitment_posts` + `recruitment_applications` tables, apply/withdraw + author decision queue, capacity-driven auto-FILLED. |

### 1.4 Phase 4 — Social growth

| Item | Note |
|---|---|
| Profile share card (P4.1) | `/v1/profiles/:userId/share-card` + `/v1/og/profile/:userId.png` (resvg-js), 60s in-memory cache. |
| Post quote (P4.2) | `post_quotes` UNIQUE(quoting_post_id), DTO `quoted_post: PostQuoteRefDTO`, depth-1 quote block render. |
| Follow recommendations (P4.3) | `follow_recommendations` table, Jaccard scorer, daily 03 KST cron on advisory lock 854_311 (moved from 854_303 in the Phase 7 pre-PR hotfix to avoid a clash with event-live-archive), recommended-people strip. |
| Saved collections (P4.4) | `saved_collections` table (max 20/user, name 1–50), folder tab in saves screen, move/edit. |
| Profile activity pagination (P4.5) | `getActivityFeed` with discriminated `ActivityItemDTO`, cursor base64 `{type,id,created_at}`, filter chips. |
| Weekly digest (P4.6) | `WeeklyDigestService`, opt-in flag in `notification_preferences`, Sun 18:00 KST cron on advisory lock 854_304. |

### 1.5 Phase 5 — Ops & trust

| Item | Note |
|---|---|
| Rate limit (P5.1) | `RateLimitService` sliding window, `TieredThrottlerGuard` consuming `TrustScoreService`, named decorators on hot write endpoints, `429 + Retry-After`. Shadow mode default. |
| Spam auto-moderation (P5.2) | DUPLICATE_POST_HASH / REPORT_FLOOD / RAPID_FIRE_POSTS rules, SYSTEM sentinel actor, viewer sees `auto_moderation_reason` banner on own hidden post. |
| Moderation bulk actions (P5.3) | `report.service.ts::bulkResolve`, shared `batch_id`, admin multi-select + sticky action bar. |
| Audit log viewer (P5.4) | `GET /admin/audit-log` + CSV stream, admin filter form. |
| Analytics retention (P5.5) | Daily cron on advisory lock 854_401, 180d horizon, streamed CSV/JSONL export. |
| System health (P5.6) | In-memory ring metrics, `GET /admin/system-health`, admin dashboard sparkline card. |

### 1.6 Phase 6 — SNS competitiveness

| Item | Note |
|---|---|
| Mention (P6.1) | `mentions` table, regex `/@([가-힣a-zA-Z0-9_]{2,20})/g`, recipient cap 20/post, mobile `@` autocomplete + tappable render. |
| Block + Mute (P6.2) | `user_blocks` + `user_mutes` tables, global `BlockMuteService` with bidirectional `assertNotBlocked`, mobile `/me/blocks` + `/me/mutes` management. |
| Notification grouping (P6.3) | `notifications.group_key` + `updated_at`, 1h window, actors append + dedupe + cap 10, opt-in via groupKey null vs string. |
| Multi-emoji reactions (P6.4) | 6-emoji palette (HEART/THUMBS_UP/FIRE/THINK/IDEA/LAUGH), `reaction_counts` map in PostDTO, long-press picker, LIKE→HEART read-time shim. |
| Polls (P6.5) | `polls` + `poll_options` + `poll_votes` tables, 2–6 options, single-vote default, poll widget with progress bars. |
| Boost / Repost (P6.6) | `post_boosts` UNIQUE(post,booster), access-policy-gated, retweet sheet (long-press 🔁) for BOOST vs QUOTE. |
| Reply controls (P6.7) | `posts.reply_policy` enum (ANYONE/FOLLOWERS/MENTIONED_ONLY/DISABLED), `assertReplyAllowed()` gate, composer chip. |
| Event live mode (P6.8) | `event_live_posts` table, RSVP=ATTENDED + IN_PROGRESS window write, +48h archive cron on advisory lock 854_303. |
| Curator portfolio (P6.10, Tier 3) | `GET /v1/profiles/:userId/curator-portfolio` (resolved APPROVED contributions + introduced source-tier rules + P2.2 reputation; admin reverts self-prune), mobile `CuratorPortfolioScreen` gated to curator roles. No new schema. |
| Topic Hub Memory (P6.11, Tier 3) | `GET /v1/me/memories` (365/730d-ago RoomFollow / APPROVED contribution / EventRsvp anniversaries, accessPolicy-gated + HIDDEN/DELETED filtered, SavedItem excluded), Home "오늘의 기록" card auto-hiding on empty days. No new schema. |
| Room roles (P6.12, Tier 3) | `room_roles` table + owner-only grant/revoke (`POST`/`DELETE /v1/rooms/:slug/roles`) + `RoomRoleService.canModerateRoom`, mobile owner-only `RoomModeratorsScreen` + moderator badge. Follow-up: wiring `canModerateRoom` into the report-resolve path is plan-mode — see §3 + NEXT_BACKLOG §1.4. |

### 1.7 Phase 7 — identity-strengthening algorithm layer

All three are deterministic + explainable (no ML, no For-You feed —
each surface shows the user WHY it recommended something).

| Item | Note |
|---|---|
| Topic Hub similarity (P7.1) | `topic_hub_similarity` table + Jaccard scorer (contributor 0.7 + room 0.3), daily 03:30 KST cron on advisory lock 854_305, `GET /v1/topic-hubs/:slug/similar` (Public, accessPolicy-filtered), mobile `SimilarTopicHubStrip` with "공통 기여자 N명 / 공통 방 K개" reason chip. |
| Knowledge validation + chain (P7.2) | `GET /v1/knowledge-blocks/:id/validation` (deterministic score → 검증 부족/진행 중/충분히 검증됨 label + 4 signals) + `/chain` (person-centric timeline), index `knowledge_contributions_target_status_idx`, mobile validation badge + signals sheet + `BlockChainTimelineScreen`. |
| Event recap auto-draft (P7.3) | `POST /v1/event-cards/:id/recap/suggest` (organizer gate: room owner OR VERIFIED_PLANNER, COMPLETED-only), no new schema (synthesizes EventReview/EventLivePost/EventRsvp), mobile `RecapDraftCallToAction` → composer prefill via `PostComposerArgs`. |

### 1.8 F-series follow-ups

| Item | Note |
|---|---|
| MetricsService wired at call sites (F5) | search / media / push / rate-limit record p50/p95 + error counts. |
| Profile edit (F15) | nickname uniqueness collision (409) + avatar upload via MediaRepository, edit sheet now requires `initialNickname` + `initialAvatarUrl`. |
| Default-like tap (F16) | Every PostCard's heart routes through ReactionService.toggle (default HEART) — long-press still opens the palette. |
| Retweet sheet (F17) | Long-press on 🔁 opens BOOST vs QUOTE bottom sheet; QUOTE prefills composer with `quoted_post_id`. |
| Drill-down back-button (F14) | Detail navigations use `push` not `go` so the back arrow always works. |
| Backfill scripts (F11) | Five idempotent scripts (`backfill_revisions`, `backfill_reputation`, `backfill_reference_tiers`, `migrate-uploads-to-r2`, `backfill_recruitment_posts`) with dry-run option. |

### 1.9 Current green gates

Re-run against HEAD before each release attempt. After refactor A the
mobile baseline is **157 passing tests, 0 failing** (the 12
pre-existing brittle visual-smoke / ops / profile failures were fixed
by stubbing the Dio-firing providers + the `CrashlyticsBootstrap`
late-init guard).

| Gate | Command |
|---|---|
| Static analysis | `cd apps/mobile && flutter analyze` |
| Mobile widget + unit tests | `cd apps/mobile && flutter test` |
| API unit tests | `npm run api:test` |
| API e2e | `npm run api:test:e2e` |
| Debug APK | `cd apps/mobile && flutter build apk --debug` |
| Release AAB (dry-run) | `cd apps/mobile && flutter build appbundle --release` |
| Brand asset pipeline | `bash scripts/check-mobile-assets.sh` |
| Release-signing structure | `bash scripts/check-release-signing.sh` |
| Type-check | `npx tsc --noEmit -p apps/api/tsconfig.json` |

---

## 2. Implemented, env/operator required

Code is in place — runtime stays in stub / disabled mode until an
external account, credential, or domain lands. The right-hand column
is the bare minimum the operator must provide for the surface to flip
from "wired" to "live".

| Area | What's wired | What operator must provide | Where it goes |
|---|---|---|---|
| Kakao OAuth (P1.1) | `kakaoAuthorizeUrl` + `loginWithKakao` + `oauth_states` + `flutter_web_auth_2` integration | KCP business app, REST/native keys, redirect URI registered | `KAKAO_REST_API_KEY` / `KAKAO_CLIENT_SECRET` / `KAKAO_REDIRECT_URI` |
| FCM push (P1.2) | `firebase-admin` import + `PushDelivery` SDK call + `device_tokens` + `firebase_messaging` mobile + token registration round-trip + token-revoke on invalid response | Firebase project + service account JSON + `google-services.json` (Android) | `FIREBASE_SERVICE_ACCOUNT_JSON` / `FIREBASE_SERVICE_ACCOUNT_PATH` / `NOTIFICATION_DELIVERY_MODE=push` |
| Crashlytics (P1.3) | `firebase_crashlytics` init + `FlutterError.onError` + `PlatformDispatcher.onError` + Crashlytics Gradle plugin | Same Firebase project as P1.2 + symbol upload in release pipeline | `PRISM_CRASHLYTICS_ENABLED` dart-define + `:app:uploadCrashlyticsSymbolFileRelease` task |
| R2 media + CDN (P1.4) | `s3-media-storage.ts` accepts `S3_ENDPOINT` / `MEDIA_PUBLIC_BASE_URL`, sharp pipeline for `thumb` + `md` variants, `media_assets.cdn_url` / `variants` columns | Cloudflare R2 bucket + R2 access tokens + CDN hostname | `MEDIA_STORAGE_MODE=s3` + `S3_ENDPOINT` + `S3_ACCESS_KEY_ID` + `S3_SECRET_ACCESS_KEY` + `MEDIA_PUBLIC_BASE_URL` |
| Share / deep link (P1.5) | `/v1/share/preview` + `/v1/share/resolve` + mobile `/share/:type/:id` router + `share_plus` + Android App Links intent-filter | Cloudflare Worker (or static SSR) at the chosen domain + `assetlinks.json` with release keystore SHA-256 | Hosting + DNS + `mobile:check-assets` covers MIME |
| Email delivery (M17 boundary) | `IEmailDelivery` boundary + Korean template helper | Resend / Postmark / SES account + API key | `EMAIL_PROVIDER` / `EMAIL_API_KEY` / `EMAIL_FROM_ADDRESS` |
| Production API base URL | Mobile resolver covered by `apps/mobile/test/config_test.dart` (11 cases) | DNS + TLS termination for `api.club.prism.app` (or chosen production hostname) | `--dart-define=API_BASE_URL=…` at build |
| Android upload keystore | `signingConfigs.release` reads `key.properties` or falls back to debug with a Gradle warning. `scripts/check-release-signing.sh` enforces the gitignore. | `keytool -genkey` + vaulted `.jks` + populated `key.properties` on release host | Operator |
| Privacy policy URL | Draft answers in `PRIVACY_DATA_INVENTORY.md` | Legal review + publicly hosted URL | Play / App Store paperwork |
| Play Console paperwork | Listing copy skeletons + Data Safety inventory in `PLAY_INTERNAL_TESTING.md` | Account, Data Safety form, Korean screenshots, tester group | Operator |

---

## 3. Planned (still backlog)

Engineering work explicitly named in the Phase 6 / Beta-prep plan that
has NOT landed. These are the canonical post-Beta follow-ups; refer to
[NEXT_BACKLOG.md](NEXT_BACKLOG.md) for sequencing.

| Item | Source | Note |
|---|---|---|
| P6.9 — Scoped DM (workflow-bounded) | Phase 6 plan §Tier 3 | Recruitment + contribution closed channels only. Deferred to post-Beta. (P6.10/6.11/6.12 have shipped — see §1.6.) |
| P6.12 follow-up — delegated moderation → report-resolve wiring | Phase 6 plan §Tier 3 | `canModerateRoom` ships but isn't consumed by `ReportService.resolve()`/`getDetail()`/`listQueue()` yet (all global `isModerator`-gated, queue is global). Room-aware authz + a room-scoped `GET /v1/rooms/:slug/reports` queue is a plan-mode change on the security-critical path. See NEXT_BACKLOG §1.4. |
| iOS scaffold (`apps/mobile/ios/`) | this doc historically | `flutter create --platforms=ios .` from a macOS host. Out of scope for Play Internal — separate workstream. |
| Scroll-aware visual smoke for Home / Room / PostDetail / Profile | improvement plan §2 | Today only Sliver-based screens use `expectNoOverflowWhileScrolling`; ListView screens fall back to the simpler helper. Defensive. |
| Mobile login picker swap | improvement plan §3 | Real `/auth/login` form is implemented (`features/auth/ui/login_screen.dart`). The dev persona picker remains under `/dev/login` for tests + smoke; only the route-mounting decision is left. |
| Auto-mod shadow-mode telemetry surface | improvement plan §4 | Auto-mod already records to analytics; surface a "today's rule hits" card in admin Ops. |

---

## 4. Intentionally omitted

The product brief + Phase 6 plan §"명시적 거부" rule out these
explicitly. This table is the canonical "we already considered this
and said no" reference for future PR review.

| Item | Why omitted |
|---|---|
| Algorithmic For You feed | `docs/00_PRISM_CLUB_BRIEF.md:14, 137-147` — deterministic ranking is the product position. |
| 24h Stories | Knowledge persistence is the asset; P6.8 Event live mode covers the bounded use case. |
| Reels / short video | Infra + moderation cost; PRISM Event video stays an external link. |
| Open 1:N group DM | Moderation cost; Room covers the group conversation surface. P6.9 covers the workflow-bounded variant. |
| Live broadcast (Twitter Spaces / IG Live) | Infra cost + moderation surface; out of brand identity. |
| Marketplace / payment | PRISM Event app handles checkout. |
| ActivityPub / Fediverse | Single-tenant Korean app; interop is not the product. |
| Hashtag (unrestricted free-form) | Conflicts with Topic Hub curation. Curated cross-cutting tags (admin-blessed only) is the Beta-prep alternative if data justifies it. |
| Public Pages (FB-style) | Curator portfolio (P6.10) is the role-aligned alternative. |

---

## 5. Operator-owned gaps (the actual upload blockers)

Same items as §2 but ordered by what unblocks the first Internal AAB.

1. **Upload keystore** generated + vaulted; `key.properties` populated
   on the release host.
2. **Play Console app** created + Play App Signing enrolled.
3. **Privacy policy URL** publicly hosted (Korean primary).
4. **Data Safety form** filled to match the code state in §1 + §2.
5. **≥ 2 phone screenshots** captured from the installed Internal AAB;
   Korean short + full description.
6. **Tester group** created + opt-in URL distributed.
7. **≥ 1 filled** [`MOBILE_DEVICE_QA_LOG.md`](MOBILE_DEVICE_QA_LOG.md)
   on Pixel + ≥ 1 on Galaxy.

For the Production promotion (post-Internal): also FCM project, R2
bucket + CDN, production API DNS + TLS, Kakao biz app.

---

## 6. Go / no-go checklist for Play Internal Testing

The §5 operator items are the ones the Play Console blocks on. The
§1.8 engineering gates must all be green at HEAD on the release-tag
commit.

- [ ] Engineering gates green (`flutter analyze` / `flutter test` /
      `mobile:check-assets` / `mobile:check-signing` / `npm run
      api:test` / `npm run api:test:e2e`).
- [ ] `key.properties` populated on the release host; release AAB
      built with **no** `[prism-club] android/key.properties not
      found` warning.
- [ ] `keytool -list -printcert -jarfile app-release.aab` fingerprint
      matches the operator's upload key (not the debug keystore).
- [ ] `versionCode` strictly higher than any previous upload.
- [ ] Play Console app created; Play App Signing enrolled.
- [ ] Privacy policy URL public + listed in Play Console.
- [ ] Data Safety form filled — Push (Crashlytics + FCM) marked
      according to whether operator has wired §2 rows.
- [ ] App content sections all green in Play Console (App access, Ads,
      Content rating, Target audience).
- [ ] ≥ 2 phone screenshots uploaded.
- [ ] Short + full description in Korean.
- [ ] At least 1 filled [MOBILE_DEVICE_QA_LOG.md](MOBILE_DEVICE_QA_LOG.md)
      with verdict SUBMIT against the AAB you're about to upload.
- [ ] Tester group created + opt-in URL ready to distribute.

Tick → upload → smoke from a tester device via the opt-in URL →
promote to Closed / Open / Production through the same console once
the Production-only operator rows in §2 clear.

---

## 7. Re-audit policy

This doc moves between two states:

- **Stable** — engineering hasn't shipped any plan-tagged work since
  the last `## §1` revision. Keep editing in place.
- **Reset** — a Phase landed (e.g. Phase 7 begins) and §1 needs
  re-categorization. Bump the snapshot line at the top and re-run §2's
  right-hand column against actual env files.

The `> Reset (...)` line at the top is the contract: anyone re-reading
this doc trusts §1–§4 against that commit. Outdated reset lines are a
review red flag.
