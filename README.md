# PRISM Club

PRISM Club은 예능 콘텐츠, 오프라인 이벤트, 놀이 경험, 프로그램 레퍼런스를 주제별로 모아
이야기하는 PRISM 생태계의 지식형 커뮤니티 프로젝트입니다. 주제명을 클릭하면 단순 게시판이
아니라 개요, 핵심 정보, 이벤트 데이터, 레퍼런스, FAQ, 관련 방이 모인 **Topic Hub**로 들어가고,
그 위에 유저가 만든 방과 타임라인형 대화가 쌓이는 구조를 지향합니다.

## Status

Milestone 1 — vertical slice. 참가자 → 연애 콘텐츠 Topic Hub → user room → post →
replies flow.

Milestone 2 — knowledge contribution + curation loop. Members propose edits
or new knowledge blocks on a Topic Hub; a curator approves / rejects /
requests changes; approved contributions update the block and capture an
audit snapshot.

Milestone 3 — unified search across Topic Hub, knowledge blocks, rooms,
posts, event cards, and references. Includes "popular topics" suggestions
that double as search-screen empty state and Topic Hub "관련 검색" chips.

| Surface | What works |
|---|---|
| Backend (NestJS + Prisma) | 27 endpoints, stub auth + role gate, mock Events client, deterministic seed with curator persona, ILIKE-based search |
| Mobile (Flutter) | Login picker, Space list (search icon + curator banner + 내 제안 entry), Category list, Topic Hub (search icon + 관련 검색 chips + 정보 개선 제안 + per-block 개선), Room create, Room timeline, Post compose, Post detail with 2-level reply tree + like, Contribution composer, My contributions, Curation queue, Curation detail, Search screen with type filter |
| Tests | 47 backend unit tests + 3 e2e + 16 Flutter widget tests, all green |
| Smoke | `scripts/smoke.sh` — 24 curl-driven checks (M1 slice + M3 search) |

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
├── docs/             # planning docs (00–05)
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
npm run api:test          # 47 unit tests, 8 suites (M1 + M2 + M3)
npm run api:test:e2e      # 3 e2e: M1 slice + M2 contribution + M3 search
bash scripts/smoke.sh     # 24 curl-driven checks (api must be running)

# Mobile
cd apps/mobile
flutter analyze
flutter test              # 16 widget tests (M1 + M2 + M3)
flutter build web --no-tree-shake-icons   # full compile check
```

## Seed personae

`npm run db:seed` produces four users — pick any from the in-app login
picker. They drive the seeded posts/replies and contribution flow.

| Nickname | Persona |
|---|---|
| 민서 (minseo) | Demo post author of the 소개팅 미션 나이트 review |
| joon | Common replier; contributor of the seeded APPROVED FAQ edit |
| haneul | Owner of the 환승연애식 오프라인 토크 게임 (user-created) room |
| coral | **Curator** — only persona that can approve/reject contributions |

The seed also creates two `Space`s (`participant`, `planner`). Planner is
visible but locked in the UI — the access-control structure is ready without
surfacing the verification flow.

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

## What's deferred

Notifications, bookmarks, moderation / reports / audit-log table, real
OAuth, URL metadata scraping, real-time updates, image upload, the
planner verification flow, the admin web, multi-evidence per contribution,
versioned block history beyond the per-contribution snapshot, editing a
pending contribution before approval, concurrent-edit conflict resolution
across approvals, query history / dynamic popular queries, FTS or a Korean
tokenizer, external search engines, search inside replies, personalized
ranking or "for you" recommendations. See the plan file's
§8 risks / deferred list for the full breakdown.
