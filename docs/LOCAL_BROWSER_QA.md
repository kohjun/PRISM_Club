# PRISM Club — Local Browser QA

The fast path for running PRISM Club end-to-end on your laptop, in
Chrome, backed by the local NestJS API and local Docker Postgres. This
is the recommended QA mode while we are **not** deploying staging or
production — it's the same code paths, just on `localhost`.

> **This is local QA only.** It is not the official release surface —
> the official release will be the native Flutter app (Android / iOS).
> For staging stand-up see
> [STAGING_BRINGUP_CHECKLIST.md](STAGING_BRINGUP_CHECKLIST.md).

Pairs with:

- [README.md](../README.md) — the top-level prerequisites + scripts
- [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md) — the persona-by-persona QA
  flows; this guide reuses them locally
- [BETA_READINESS.md](BETA_READINESS.md) — the feature map being tested

---

## 1. One-time prerequisites

You only do this once per workstation.

- [ ] Node.js ≥ 20 on PATH (`node --version`).
- [ ] Docker Desktop running.
- [ ] Flutter ≥ 3.41 on PATH (`flutter --version`). Chrome bundled with
      Flutter or installed on PATH.
- [ ] Repo cloned at the target commit, `npm install` has been run at
      the repo root.

If any of those is missing, fix it before continuing.

---

## 2. Local startup sequence

The five-step boot. Run these in order, in **four terminals**.

### 2.1 Postgres (terminal 1, one-shot)

```bash
docker compose up -d postgres
docker compose ps postgres
```

Expect `postgres` showing `Up (healthy)`. Host port **5433** → container
5432 (the compose file maps this so a Windows-installed PostgreSQL on
5432 doesn't shadow the dev DB).

### 2.2 Env + migrations + seed (terminal 1)

```bash
cp .env.example .env                # idempotent; skip if .env exists
npx prisma migrate dev              # applies every migration on dev DB
npm run db:seed                     # six personas + fixtures
```

`npm run db:seed` prints a summary line with non-zero counts for users,
spaces, categories, topic hubs, rooms, posts, etc.

> **Apply migrations to the test DB once** (only needed before
> `npm run api:test:e2e`):
> ```powershell
> $env:DATABASE_URL = "postgresql://prism:prism@localhost:5433/prism_club_test?schema=public"
> npx prisma migrate deploy
> Remove-Item Env:DATABASE_URL
> ```
> Bash equivalent:
> ```bash
> DATABASE_URL="postgresql://prism:prism@localhost:5433/prism_club_test?schema=public" \
>   npx prisma migrate deploy
> ```

### 2.3 API dev server (terminal 2, foreground)

```bash
npm run api:dev
```

Watch-mode reload, listens on `http://localhost:3000/v1`, Swagger at
`/v1/docs`. Wait for the line `Nest application successfully started`
before moving on.

Quick sanity probe (in a third throwaway shell):

```bash
curl -sS http://localhost:3000/v1/health        # → {"ok":true}
curl -sS http://localhost:3000/v1/health/ready  # → {"ok":true,"db":"up"}
curl -sS http://localhost:3000/v1/health/version | jq .
```

### 2.4 Flutter Chrome (terminal 3, foreground)

```bash
cd apps/mobile
flutter pub get          # first run only or after pubspec changes
flutter run -d chrome
```

Flutter prints `Flutter run key commands` and the page opens
automatically. The `apiBaseUrl` resolver in
`apps/mobile/lib/core/config.dart` defaults to `http://localhost:3000/v1`
for the web target — no override needed for this flow.

If you want to point Chrome at a different API (e.g. local staging
container on a different port, or a remote dev API), pass
`--dart-define=API_BASE_URL=...` — the override always wins:

```bash
# Chrome against a custom local port:
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8080/v1

# Chrome against a remote dev API:
flutter run -d chrome \
  --dart-define=API_BASE_URL=https://api.dev.<your-domain>/v1
```

Trailing slashes are stripped automatically. See
[FLUTTER_NATIVE_SETUP.md](FLUTTER_NATIVE_SETUP.md) §4 for the full
target × override matrix.

### 2.5 Admin web (terminal 4, optional)

Useful when you want to drive the curator / moderator surfaces in a
denser desktop-first layout.

```bash
npm run admin:dev
```

Serves on `http://localhost:5180`. The login form's "API base URL"
input defaults to `http://localhost:3000/v1`; paste a seeded persona
UUID (preferably **coral** — see §4) and submit.

---

## 3. Seeded persona login table

Each persona is signed in via the **login picker** on the Flutter web
client, or via the **user_id field** on the admin web login form. The
UUIDs are committed in `prisma/seed.ts` and are stable across reseeds.

| Nickname | UUID | Roles | Use for |
|---|---|---|---|
| 민서 (minseo) | `11111111-1111-1111-1111-111111111111` | MEMBER | Default member flows; has seeded posts + saves + follows |
| joon | `22222222-2222-2222-2222-222222222222` | MEMBER | Replier / reporter; lighter activity |
| haneul | `33333333-3333-3333-3333-333333333333` | MEMBER | Owner of the seeded user-created room |
| coral | `44444444-4444-4444-4444-444444444444` | CURATOR + MODERATOR | Admin web; `/admin/ops`, `/admin/reports`, `/curate` |
| studio_lead | `55555555-5555-5555-5555-555555555555` | VERIFIED_PLANNER | Planner space + recruitment posts |
| studio_mate | `66666666-6666-6666-6666-666666666666` | VERIFIED_PLANNER | Co-planner; lighter activity |

> The persona UUIDs are well-known. Use them locally without worry;
> never use them in staging or production. The seed script refuses to
> run with `NODE_ENV=production` unless `CONFIRM_DESTRUCTIVE_SEED=1` is
> set, so the only path that produces these accounts is dev / local.

---

## 4. QA flow checklist

For each new feature or change, walk this list in Chrome with two
browser windows open (one as a Member, one as Coral or a planner) so
you can verify both author and viewer perspectives.

- [ ] Login picker → pick **minseo** → lands on `/home`.
- [ ] `/home` renders the bundle (followed-room updates, recommended
      rooms / events, trending posts, active hubs, recent saves,
      unread notification count).
- [ ] **검색** tab → query "후기" / "환승연애" → results grouped by
      entity type.
- [ ] **커뮤니티** → 참가자 → 연애 콘텐츠 → Topic Hub renders with
      blocks + signals + related rooms + related events.
- [ ] Tap a related event tile → `/events/<cardId>` Event Detail
      renders.
- [ ] Tap a related room → timeline. Tap **팔로우**; the count
      increments and the button flips.
- [ ] Composer → text post → appears in timeline.
- [ ] Composer → text + image (jpg/png/webp/gif < 5 MB) → image
      thumbnail renders in timeline. URL is `/uploads/<uuid>.<ext>`.
- [ ] Tap a post author → `/users/<id>` profile; tap **팔로우**.
- [ ] Open `⋯` menu on a post → 신고 → submit. Subsequent submits
      for the same target return 409.
- [ ] **알림** tab → seeded notifications listed; tap one → marked
      read; unread badge decrements.
- [ ] **저장** tab → bookmark/unbookmark a post; filter chips
      partition POST / REFERENCE / EVENT_CARD.

In a second window as **coral**:

- [ ] SpaceList shows **검수 큐로 가기** + **운영 대시보드** banners.
- [ ] **운영 대시보드** → counters non-zero; deep-links work.
- [ ] **시그널 새로고침** AppBar action → success snackbar.
- [ ] `/admin/reports` shows the report submitted in the Member
      window. Resolve with HIDE → the reported post disappears from
      the Member window's timeline / search / `/home` / profile
      activity / saves.
- [ ] `/curate` → APPROVE a pending contribution → block content
      updates + audit snapshot recorded.

In a third window as **studio_lead**:

- [ ] **커뮤니티** → 기획자 스튜디오 unlocks (no lock dialog).
- [ ] **모집 글쓰기** FAB → RecruitmentComposer → submit → new post
      visible in timeline + search.
- [ ] Status chip toggles OPEN ↔ CLOSED ↔ FILLED on the planner's
      own posts.

The full per-section detail is in [BETA_QA_SCRIPT.md](BETA_QA_SCRIPT.md).
For local QA, this condensed version is enough; switch to the full
script before the cut-over rehearsal.

---

## 5. Headless verification (parallel to browser QA)

Run these to make sure the local build matches the green baseline. The
browser flow above tests behavior; these test that the headless suite
still passes after your changes.

```bash
# Backend
npm run api:test          # ~158-180 unit tests, all green
npm run api:test:e2e      # ~43-50 e2e tests, all green
npm run admin:typecheck   # exit 0

# Flutter
cd apps/mobile
flutter analyze           # info-only items OK; no errors / warnings
flutter test              # 53+ widget tests
flutter build web --no-tree-shake-icons   # full web compile
```

---

## 6. Common troubleshooting

### "Connection refused" or CORS error in Chrome

The API isn't running, or it's bound to a different port. Check
terminal 2 — does it show `Listening on port 3000`? Try
`curl -sS http://localhost:3000/v1/health` from another shell.

### Flutter web stuck on a white page

Open Chrome DevTools → Console. If you see `Failed to fetch` errors
pointing at `http://localhost:3000/v1/...`, the API isn't up. If you
see a TypeError or a syntax error, run
`cd apps/mobile && flutter clean && flutter pub get` and re-launch.

### Login picker shows no personas / "/dev/users" returns empty

The seed wasn't applied. Re-run §2.2.

### Posts / topic hubs / event detail look empty after login

Same as above — the dev DB was reset but the seed didn't run. Re-run
`npm run db:seed`.

### `docker compose up` says port 5433 already in use

A previous Postgres container or a host PostgreSQL service is on 5433.
Stop it first (`docker compose down`) or change the host port mapping
in `docker-compose.yml`.

### Migration error: P3009 / "migration failed"

The dev DB has drifted from the migrations directory. Reset and
reseed:

```bash
npm run db:reset      # drop + recreate dev DB, auto re-seeds
```

This is destructive against the **dev** DB only. The staging seed
guard rail (`CONFIRM_DESTRUCTIVE_SEED=1`) is documented in
[STAGING_SETUP.md](STAGING_SETUP.md) §4.4 — that gate does NOT trip
in dev because `NODE_ENV !== 'production'` locally.

### Admin web shows "access denied"

The user_id you submitted isn't a CURATOR / MODERATOR / ADMIN. Sign
back out and log in as **coral** (`4444…-4444`).

### Flutter test failures referencing `flutter_test.dart` or
codegen

```bash
cd apps/mobile
dart run build_runner build --delete-conflicting-outputs
```

(only required if you edited a `@freezed` class without re-running
codegen).

---

## 7. Reset commands

When local state gets weird, blow it away and start over.

### Full DB reset (dev only — preserves migrations + seed)

```bash
npm run db:reset
# Drops + recreates prism_club, applies every migration, runs the
# seed. Takes ~10 seconds.
```

### Wipe Docker volume entirely (last resort)

```bash
docker compose down
docker volume rm prism_club_prism_postgres_data
docker compose up -d postgres
npx prisma migrate dev
npm run db:seed
```

This also clears the test DB if you'd previously applied migrations
there — repeat the `DATABASE_URL_TEST` step from §2.2 once after.

### Clear browser storage (Flutter web localStorage)

DevTools → Application → Storage → Clear site data. Wipes the JWT
the Flutter client persisted via `shared_preferences`. On the next
load the login picker reappears.

### Clean Flutter build artifacts

```bash
cd apps/mobile
flutter clean
flutter pub get
flutter build web --no-tree-shake-icons
```

---

## 8. Quick reference card

```bash
# One-shot boot from a clean clone:
npm install                                                 # repo root
docker compose up -d postgres
cp .env.example .env
npx prisma migrate dev
npm run db:seed
npm run api:dev                                             # terminal 2

# Then in another shell:
cd apps/mobile && flutter pub get && flutter run -d chrome

# Optional admin:
npm run admin:dev                                           # terminal 4 → http://localhost:5180

# Reset if state goes weird:
npm run db:reset

# Headless verification:
npm run api:test && npm run api:test:e2e && npm run admin:typecheck
cd apps/mobile && flutter analyze && flutter test && flutter build web --no-tree-shake-icons
```
