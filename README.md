# PRISM Club

PRISM Club은 예능 콘텐츠, 오프라인 이벤트, 놀이 경험, 프로그램 레퍼런스를 주제별로 모아
이야기하는 PRISM 생태계의 지식형 커뮤니티 프로젝트입니다. 주제명을 클릭하면 단순 게시판이
아니라 개요, 핵심 정보, 이벤트 데이터, 레퍼런스, FAQ, 관련 방이 모인 **Topic Hub**로 들어가고,
그 위에 유저가 만든 방과 타임라인형 대화가 쌓이는 구조를 지향합니다.

## Status

**Alpha RC** — M1–M13 + hardening complete. See
[ALPHA_RC_CHECKLIST](docs/ALPHA_RC_CHECKLIST.md) for the feature map, demo
walkthrough, fresh-start flow, and RC verification steps. See
[NEXT_BACKLOG](docs/NEXT_BACKLOG.md) for the prioritized post-Alpha items
(deployment, real PRISM EVENT integration, production media storage, push,
admin web, analytics).

Milestone 13 — real auth sessions. Replaces the stub `X-User-Id` with a
JWT-backed flow. `POST /v1/auth/login` (passwordless: accept a seeded
user id, return signed JWT + session DTO), `GET /v1/auth/session`,
`POST /v1/auth/logout` (no-op stub for the stateless design). The shared
`AuthGuard` now accepts either `Authorization: Bearer <jwt>` (preferred)
or — only in non-production / `ALLOW_X_USER_ID=1` — the legacy
`X-User-Id` header that tests and the smoke script keep using. Flutter
`CurrentUser` carries the access token in `SharedPreferences`; the Dio
interceptor adds `Authorization: Bearer …` automatically. The login
picker now actually calls `/auth/login` before navigating. `JWT_SECRET`
in `.env.example` MUST be overridden in non-dev environments.

Milestone 1 — vertical slice. 참가자 → 연애 콘텐츠 Topic Hub → user room → post →
replies flow.

Milestone 2 — knowledge contribution + curation loop. Members propose edits
or new knowledge blocks on a Topic Hub; a curator approves / rejects /
requests changes; approved contributions update the block and capture an
audit snapshot.

Milestone 3 — unified search across Topic Hub, knowledge blocks, rooms,
posts, event cards, and references. Includes "popular topics" suggestions
that double as search-screen empty state and Topic Hub "관련 검색" chips.

Milestone 4 — planner community + staff recruitment. `Space.access_policy`
is now enforced through `AccessControlService`: plain members are blocked
from the planner space (categories, topic hub, rooms, posts, and search
results), while seeded Verified Planners can read, write, and toggle
recruitment-post status. Recruitment posts reuse `Post.recruitment_fields`
(role / schedule / location / compensation / capacity / application_method
/ status) — no schema migration.

Milestone 5 — event discussion surfaces. EventCard is now an entry point,
not just an inline chip. A new `GET /v1/event-cards/:id` endpoint returns
the local snapshot + related rooms (PIN ∪ POST_ATTACHMENT, deduped) +
related posts (paged) + `default_compose_room_slug` (falls back via
`topic_hub_event_links` when no room directly references the event).
Access-policy filtering is reused from M4 so non-planners never see
planner-space rooms/posts in the bundle. A new mobile `EventDetailScreen`
at `/events/:cardId` is reachable from every former EventCard tap target
(TopicHub related events, RoomTimeline pins, PostDetail attachments,
Search results); the old search-result bottom sheet is retired. The
"글 작성" CTA routes to the existing composer with
`?attach_event_card_id=<id>` so the event is pre-attached (and still
removable). No schema migration; mock `IEventsClient` is unchanged.

Milestone 6 — lightweight retention loop: follow rooms, save items,
notification inbox. Three new schema tables (`room_follows`, `saved_items`,
`notifications`) and six new API endpoints power a retention layer with no
push/email/realtime infrastructure. Followers of a room receive
`NEW_POST_IN_FOLLOWED_ROOM` notifications when a post is created; replies
trigger `REPLY_ON_POST` / `NESTED_REPLY`; recruitment status changes emit
`RECRUITMENT_STATUS_CHANGED`; approved/rejected contributions emit
`CONTRIBUTION_RESOLVED`. Notification access is filtered at read time by
`spaceAccessPolicy` stored in the payload, consistent with M4 role gates.
`Post.bookmarkCount` (dormant since M1) is now activated: incremented and
decremented transactionally in `SaveService.toggle()`. New Flutter screens:
`NotificationScreen` at `/me/notifications` (with mark-all-read) and
`SavedItemsScreen` at `/me/saves` (type chip filter). AppBar surfaces:
bell icon + unread badge in `SpaceListScreen`, follow button in
`RoomTimelineScreen`, bookmark icon in `PostDetailScreen` and
`EventDetailScreen`.

Milestone 7 — personalized home feed. A new `HomeModule` exposes two endpoints:
`GET /v1/home` returns a one-shot bundle with 7 sections (unread notification
count, followed-room updates, recommended rooms, recommended events, trending
posts, active topic hubs, recent saves); `GET /v1/home/feed` returns a
cursor-paginated flat list of the same content with typed `reason` labels.
All scoring is deterministic — trending posts use `likeCount×3 + replyCount×2
+ bookmarkCount`; recommended rooms use `followerCount×2 + postCount` and
exclude already-followed rooms — so tests remain stable without mocking.
Access control is consistent with M4–M6: member viewers never see
PLANNER_ONLY content in any section. No new schema. A new `HomeShellScreen`
wraps the five main tabs (홈 / 검색 / 커뮤니티 / 저장 / 알림) in a Material 3
`NavigationBar`; the post-login redirect now lands on `/home` instead of
`/spaces`. All existing deep-link routes are preserved.

Milestone 12 — activity signals. TopicSignal rows are now computed from real
post activity instead of static seed data. `POST /v1/admin/signals/refresh`
(role-gated to CURATOR/MODERATOR/ADMIN) walks every TopicHub, looks at the
posts in its category's rooms over a 30-day window, and writes deterministic
signal entries: HOT_DEBATE (post with most replies), POPULAR_REF (post with
most likes), VERIFIED_REVIEWS (count of recruitment posts). Existing
TopicHub bundle continues to surface signals via the `signals` field, but
now reflects live activity. `GET /v1/topic-hubs/:id/signals` returns
computed signals for any single hub with access-policy filtering — member
viewers get an empty array for PLANNER_ONLY hubs. OpsDashboardScreen gains
a "시그널 새로고침" action that calls the refresh endpoint and shows a snackbar.

Milestone 11 — ops dashboard. A single role-gated operational surface inside
the Flutter app (no separate Next.js admin yet). `GET /v1/admin/ops/summary`
returns pending knowledge contribution count, open report count, recruitment
post counts (open / total), and 30-day-recent users / rooms / posts with up
to 5 sample items each. Endpoint requires CURATOR, MODERATOR, or ADMIN.
Flutter `OpsDashboardScreen` at `/admin/ops` renders counter cards that
deep-link into the existing curation queue, moderation queue, profile, room
timeline, and post detail surfaces. SpaceListScreen gains an `_OpsBanner`
visible only when `MeDto.isOps == true` (curator OR moderator OR admin).

Milestone 10 — media attachments. Adds `MediaAsset` table (id, owner_id,
kind, filename, mime_type, size_bytes, path) and `POST /v1/media/upload`
(multipart, image-only, 5MB cap, jpg/png/webp/gif). Files are stored locally
in `apps/api/uploads/` and served at `/uploads/<id>.<ext>` via Nest's static
middleware. **This is dev/local storage only — no S3, no CDN, no production
pipeline yet.** `PostAttachment` gains an `IMAGE` attachmentType alongside
`EVENT_CARD` / `REFERENCE`; posts can mix all three. Flutter composer adds
an 이미지 picker (via `file_picker`) with inline preview and remove button;
`PostCardWidget` renders thumbnails through a new `MediaImage` widget with
loading + error states.

Milestone 9 — moderation + reporting. Two new tables: `Report` (with
reporter_id / target_type / target_id / reason / details / status /
resolution / resolver_note) and `ModerationAction` (audit log). Five new
endpoints: `POST /v1/reports` (members create), `GET /v1/me/reports` (my
reports), `GET /v1/admin/reports` (queue — MODERATOR/ADMIN only),
`GET /v1/admin/reports/:id` (detail with target summary + audit history),
`POST /v1/admin/reports/:id/resolve` (HIDE/RESTORE/DISMISS — writes an
audit row and notifies the reporter). Duplicate OPEN reports from the same
reporter on the same target return 409. Self-reports on USER targets are
rejected with 400. Hide is implemented for POST and REPLY by flipping
`status` to `HIDDEN`; all read surfaces (timelines, search, home, event
detail, profile activity, saves) exclude HIDDEN content via
`status: { notIn: ['DELETED', 'HIDDEN'] }`. New `MODERATOR` role granted
to coral in seed. Flutter: `ReportSheet` bottom-sheet modal, MyReportsScreen,
ModerationQueueScreen, ModerationDetailScreen at `/admin/reports[/:id]`.

Milestone 8 — user profiles and lightweight social graph. PRISM Club now
has people, not just posts. `Profile.bio` is added (String?, 500-char cap)
and a new `UserFollow` table links followers↔followed with a unique
constraint. Four endpoints: `GET /v1/users/:id/profile` returns the full
profile bundle (user, bio/region/interests, role badges, counts, recent
posts, owned rooms, approved contributions, `is_self` / `is_following`);
`PATCH /v1/me/profile` updates bio/region/interests with server-side
validation (trim, dedupe, lowercase interests, max-counts); `POST /v1/users/:id/follow-toggle`
and `GET /v1/users/:id/follow-state` mirror M6's room-follow pattern but
reject self-follow with 400. Every activity list inside the profile bundle
runs through `accessPoliciesAllowedFor(viewer)` so a member viewing a
planner's profile never sees PLANNER_ONLY recruitment content. Counts also
filter, so the UI stays internally consistent. New Flutter screens:
`ProfileScreen` at `/users/:id` with hero block, role badges, count row,
sections (최근 글 / 만든 방 / 승인된 기여), and a follow CTA; an edit-profile
bottom sheet shows when `isSelf`. A new reusable `RoleBadgeRow` widget
renders chips for VERIFIED_PLANNER / CURATOR / ADMIN (MEMBER is implicit
and not rendered). `PostCardWidget`, `ReplyTreeWidget`, and
`ContributionCardWidget` gained an optional `onAuthorTap` callback; caller
screens (`RoomTimelineScreen`, `PostDetailScreen`, `HomeScreen`,
`MyContributionsScreen`, `CurationQueueScreen`) wire it to navigate to
`/users/:id`. The dev login picker also gets a "프로필 보기" affordance.

| Surface | What works |
|---|---|
| Backend (NestJS + Prisma) | 47 endpoints, role-gated guard, mock Events client, deterministic seed with all five roles, ILIKE-based search filtered per viewer, EventDetail bundle, follow/save/notification, home bundle + feed, profile bundle + edit + user-follow, moderation reports + audit, media upload (local dev storage at /uploads/*) |
| Mobile (Flutter) | Login picker → `/home` shell (5-tab NavigationBar), Home, Space list, Category list, Topic Hub, Room create, Room timeline, Post compose (with image picker), Recruitment composer, Post detail (image thumbnails), Contribution composer, My contributions, Curation queue, Curation detail, Search, Event Detail, Notifications, Saved items, Profile at /users/:id, Report sheet + /me/reports + /admin/reports queue + /admin/reports/:id detail |
| Tests | 121 backend unit + 35 e2e + 53 Flutter widget, all green |
| Smoke | `scripts/smoke.sh` — 75 curl-driven checks (M1–M13 inclusive) |

## Repo layout

```
.
├── apps/
│   ├── api/          # NestJS modular monolith
│   └── mobile/       # Flutter app (Android + web targets)
├── packages/
│   └── shared-types/ # (placeholder, reserved for future)
├── prisma/
│   ├── schema.prisma
│   └── seed.ts
├── docs/             # planning docs (00–05) + ALPHA_RC_CHECKLIST + NEXT_BACKLOG
├── scripts/
│   └── smoke.sh      # curl-driven slice smoke test
├── docker-compose.yml
├── package.json      # npm workspaces root
├── versions.md       # pinned tool versions
└── README.md
```

## Planning Docs

- [Project brief](docs/00_PRISM_CLUB_BRIEF.md)
- [Technical stack](docs/01_TECH_STACK.md)
- [Requirements and use cases](docs/02_REQUIREMENTS_AND_USE_CASES.md)
- [Architecture and data design](docs/03_ARCHITECTURE_AND_DATA.md)
- [UX mockups and storyboard](docs/04_UX_MOCKUPS_STORYBOARD.md)
- [Roadmap](docs/05_ROADMAP.md)
- **[Alpha RC checklist](docs/ALPHA_RC_CHECKLIST.md)** — feature map, demo walkthrough, fresh-start flow, RC verification
- **[Next backlog](docs/NEXT_BACKLOG.md)** — deferred production items

## Prerequisites

- Node.js ≥ 20 (developed against 24.13.1)
- Docker Desktop
- Flutter ≥ 3.41 with the Android toolchain on PATH (for the mobile client)

See `versions.md` for the exact versions this project was developed against.

> **Windows note:** A Windows-installed PostgreSQL on port 5432 will shadow the
> Docker container. The compose file maps host **5433** → container 5432 to
> avoid that conflict. The `.env` `DATABASE_URL` uses `localhost:5433`.

## Running locally

```powershell
# 1. install workspace deps
npm install

# 2. start postgres
docker compose up -d postgres

# 3. apply schema + seed
npx prisma migrate dev
npm run db:seed

# 4. start the API (http://localhost:3000/v1, swagger at /v1/docs)
npm run api:dev

# 5. (optional) walk the slice through curl
bash scripts/smoke.sh

# 6. start the mobile app
cd apps/mobile
flutter run                 # picks any connected device or emulator
# or:
flutter run -d chrome       # web target — fastest sanity check
```

> On Android emulator the mobile client reaches the host machine at
> `10.0.2.2`. The Flutter `apiBaseUrl` in `lib/core/config.dart` selects the
> right host automatically (`localhost` on web/iOS, `10.0.2.2` on Android).
> Override with `--dart-define=API_BASE_URL=...` for a physical device.

## npm workspace scripts

| Script | What |
|---|---|
| `npm run api:dev` | Start the API with watch-mode reload |
| `npm run api:build` | Compile the API for production |
| `npm run api:test` | Run backend unit tests (Jest, serial) |
| `npm run api:test:e2e` | Run the vertical-slice e2e test |
| `npm run db:seed` | Re-seed the dev database |
| `npm run db:reset` | Drop + recreate the dev database (then auto-seeds) |
| `npm run prisma:generate` | Regenerate the Prisma client |
| `npm run prisma:migrate` | Create a new migration in dev mode |
| `npm run prisma:studio` | Open Prisma Studio |

## Test surface

```powershell
# Backend
npm run api:test          # 82 unit tests, 10 suites (M1 + M2 + M3 + M4 + M5)
npm run api:test:e2e      # 5 e2e: M1 slice + M2 contribution + M3 search + M4 planner + M5 event detail
bash scripts/smoke.sh     # 44 curl-driven checks (api must be running)

# Mobile
cd apps/mobile
flutter analyze
flutter test              # 34 widget tests (M1 + M2 + M3 + M4 + M5)
flutter build web --no-tree-shake-icons   # full compile check
```

## Seed personae

`npm run db:seed` produces six users — pick any from the in-app login
picker. They drive the seeded posts/replies, contribution flow, and
recruitment flow.

| Nickname | Persona |
|---|---|
| 민서 (minseo) | Demo post author of the 소개팅 미션 나이트 review |
| joon | Common replier; contributor of the seeded APPROVED FAQ edit |
| haneul | Owner of the 환승연애식 오프라인 토크 게임 (user-created) room |
| coral | **Curator** — only persona that can approve/reject contributions |
| studio_lead | **Verified Planner** (M4) — owns 2 seeded recruitment posts |
| studio_mate | **Verified Planner** (M4) — owns the 음향 어시 recruitment post |

The seed creates two `Space`s. `participant` is `PUBLIC` and unlocked for
every persona. `planner` is `PLANNER_ONLY` and visible-but-locked for
plain members; tapping its card opens the lock dialog explaining the
verification requirement. studio_lead and studio_mate have full read/write
access there.

## Trying the curation loop

1. `npm run db:seed && npm run api:dev`, then `cd apps/mobile && flutter run -d chrome`.
2. Sign in as **민서**. On the Topic Hub for 연애 콘텐츠 tap "정보 개선 제안" (or the
   pencil icon next to any block) and submit a proposal with optional evidence.
3. Sign in as **coral**. The SpaceList shows a "검수 큐로 가기" banner — tap into
   `/curate`, open the proposal, hit **승인 / 거절 / 보완 요청**.
4. Return to the Topic Hub — the approved proposal is reflected in the block.
5. Sign in as 민서 again and tap "내 제안" on SpaceList — your proposal's status
   reflects the curator's decision.

The seeded data already contains 2 PENDING proposals and 1 APPROVED proposal
(with a snapshot of the pre-approval content on the contribution row,
demonstrating the audit trail).

## Trying search

1. With the API running and the mobile app open, tap the **search icon** on
   the SpaceList AppBar (or on any Topic Hub AppBar).
2. The empty state offers popular topics — "환승연애", "소개팅 미션",
   "체크리스트", "FAQ", etc. Tap a chip or type your own query.
3. Results are grouped by entity type with a chip-row filter at the top.
   Toggle a chip to narrow results.
4. Tap a Topic Hub / Knowledge / Room / Post result to navigate to the
   relevant screen. EventCard taps open a bottom-sheet detail; Reference
   taps open the external URL via the OS browser.

The Topic Hub also surfaces a small "관련 검색" chip row right under the
header — tap a chip to land on Search pre-filled with that query.

## Trying event detail

1. With the API running and the mobile app open, sign in as **민서**.
2. On the 연애 콘텐츠 Topic Hub, scroll to "관련 이벤트" — each EventCard is
   tappable. Tap **PRISM 소개팅 미션 나이트** → lands on `/events/<cardId>`
   with the hero card, "관련 방", and "관련 글" sections (1 related post:
   minseo's review).
3. Tap **글 작성** in the floating CTA. There's only one eligible room
   (`dating-event-reviews`), so the composer opens directly with the
   EventCard pre-attached under "첨부된 이벤트". Remove it via the close
   button if desired; submitting routes back to the room timeline.
4. Search "환승연애" from SpaceList — the EventCard hit now navigates to
   Event Detail directly (the M3 bottom sheet has been retired).
5. Open `evt-003`-style events through search/topic hub to see the
   empty-state copy ("아직 이 이벤트로 작성된 글이 없어요"). The CTA stays
   enabled because `default_compose_room_slug` falls through
   `topic_hub_event_links` to the OFFICIAL event-reaction room of the
   parent topic hub.

## Trying the planner community

1. With the API running and the mobile app open, sign in as **민서** and tap
   the **기획자 커뮤니티** card on SpaceList. The lock dialog explains why
   access is restricted. Searching for `스태프` returns zero post hits because
   non-planners cannot see planner-space content.
2. Sign out and sign in as **studio_lead**. Tap **기획자 커뮤니티** → enter
   `/spaces/planner/categories` → tap **스태프 / 스튜디오** → open the topic
   hub → enter **스태프 모집 공고** room. You see 3 seeded recruitment posts
   (2 OPEN, 1 CLOSED).
3. Tap a recruitment post. The `RecruitmentPostCard` renders role / schedule
   / location / compensation / capacity / application method with a status
   chip. Author-only actions in the bottom row flip the status between
   OPEN / CLOSED / FILLED.
4. The room's FAB ("모집 글쓰기") opens the structured RecruitmentComposer.
   Submit a new posting — it appears in the timeline and on Search for
   verified planners.

## Architecture decisions

- **Modular monolith** for the API (per `docs/01_TECH_STACK.md` §4). Modules:
  `shared`, `auth`, `users`, `community` (spaces/categories/rooms),
  `knowledge` (topic hubs + contributions), `event-link`, `reference`, `posts`
  (posts + replies + reactions).
- **Stub auth via `X-User-Id` + role gate.** `AuthGuard` resolves the header
  to a user and exposes roles. `RolesGuard` reads `@Roles('CURATOR','ADMIN')`
  metadata and rejects with 403. The contract is identical to what a real
  JWT-based guard will populate — the swap is one file.
- **Mock Events client** (`apps/api/src/modules/event-link/clients/mock-events.client.ts`)
  hides behind the `IEventsClient` token — swap the binding to introduce the
  real Events/Contenido client without touching callers.
- **Reply depth = 2** enforced at the service layer (per FR-REP-05).
- **`reference_items`** table — Prisma model is `Reference`; the table is
  named `reference_items` because `references` clashes with a SQL reserved
  word.
- **Counters maintained transactionally** on Post/Reply rows — no Redis yet.
- **Pin / attachment / contribution-evidence resolution**: `room_pins`,
  `post_attachments`, and `knowledge_contributions.evidence_target_id` use
  `(target_type, target_id)` without an FK; the server resolves targets in a
  second pass to keep the schema flexible.
- **Contribution audit lives on the contribution row.** On APPROVE the
  service captures `snapshot_block_type/title/body` *before* overwriting the
  target block — both writes happen in the same Prisma transaction. No
  separate `knowledge_block_revisions` table for now.
- **Search is ILIKE-based, not FTS.** Korean tokenization in the default
  Postgres FTS configs is a poor fit for our content; substring matching
  with `mode: 'insensitive'` is encoding-blind, fast at this scale, and
  trivially replaceable behind `SearchService`. `pg_trgm` indexes + GIN
  acceleration are the documented escape hatch when content grows past a
  few thousand rows per entity.
- **Popular topic suggestions are hardcoded** in `SearchService` for M3 —
  no query tracking, no analytics. The endpoint shape (`?categorySlug=`)
  is ready when we want to swap in dynamic, per-category lists later.
- **Access control is data-driven, not decorator-driven.** M4 added
  `AccessControlService` (`apps/api/src/shared/access-control.service.ts`),
  which reads `Space.access_policy` and is invoked at every read entry point
  in community / knowledge / posts / search. Plain members get `PUBLIC` only;
  `VERIFIED_PLANNER` and `ADMIN` additionally get `PLANNER_ONLY`. The same
  helper threads into `SearchService` as a Prisma relation filter so denied
  content never returns to non-planners.
- **Recruitment posts reuse `Post.recruitment_fields` JSONB.** No new tables
  or columns — the existing `post_type` + `recruitment_fields` slots from
  M1 are now actually populated. Author-only status toggle lives behind
  `POST /v1/posts/:id/recruitment-status`.
- **EventCard stays the canonical local snapshot.** M5's
  `GET /v1/event-cards/:id` aggregates pin-based + post-attachment-based
  related entities and computes counts live. The mock `IEventsClient`
  is unchanged; supplementing the snapshot with live organizer data
  (capacity, RSVP, etc.) is the deferred bridge to a real Events
  service. `default_compose_room_slug` resolves through
  `topic_hub_event_links` when no room directly references the event,
  so empty events still get a sensible compose target.

## What's deferred

Notifications, bookmarks, moderation / reports / audit-log table, real
OAuth, URL metadata scraping, real-time updates, image upload, real
application forms / payment handoff for recruitment, PRISM Studio backoffice
integration, role-grant UI (Admin → Verified Planner promotion lives only in
the seed), the admin web, multi-evidence per contribution, versioned block
history beyond the per-contribution snapshot, editing a pending contribution
before approval, concurrent-edit conflict resolution across approvals, query
history / dynamic popular queries, FTS or a Korean tokenizer, external search
engines, search inside replies, personalized ranking or "for you"
recommendations. M5-specific deferrals: ticket purchase / RSVP / capacity
countdown / organizer notes, real participant-verified review badges,
star ratings, live event metadata via a real Events service at detail-render
time, calendar export / system share, cross-event aggregation, EventCard
edit-from-Club, EventCard tap in curator/contribution evidence flows.
See the plan file's §8 risks / deferred list for the full breakdown.
