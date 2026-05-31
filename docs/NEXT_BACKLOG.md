# PRISM Club — Post-Beta Backlog

What we know we want to add after Beta. Prioritized loosely; each item
sketches the scope so the team can pick it up without re-discovering the
why.

> **Status note (post Phase 1–7 + F-series + refactor A/B/D).** What
> this doc previously listed as §1-§5 ("real auth", "wire notification
> providers", "analytics retention", "media storage polish", "admin
> bulk ops + audit log") has all landed, and so has Phase 7's
> identity-strengthening algorithm layer (P7.1 Topic Hub similarity,
> P7.2 knowledge validation + chain, P7.3 event recap auto-draft) —
> see [ARCHITECTURE_OVERVIEW.md](ARCHITECTURE_OVERVIEW.md) and
> [MOBILE_BETA_GAP_AUDIT.md](MOBILE_BETA_GAP_AUDIT.md) §1 for the
> ship status. The items that remain are below.

---

## 1. Phase 6 — Tier 3

Four Tier-3 items were carried out of the Phase 6 launch bundle. Three
have since shipped on `feat/p1-foundation` (P6.10 curator portfolio,
P6.11 Topic Hub Memory, P6.12 room roles — see
[MOBILE_BETA_GAP_AUDIT.md](MOBILE_BETA_GAP_AUDIT.md) §1.6). Only
**P6.9 Scoped DM** remains deferred to post-Beta. One P6.12 follow-up
(wiring delegated moderation into the report-resolve path) is still
open and is described in §1.4.

### 1.1 Scoped DM (workflow-bounded only) — P6.9

Open 1:N group DM stays intentionally omitted ([MOBILE_BETA_GAP_AUDIT.md](MOBILE_BETA_GAP_AUDIT.md) §4).
This adds **scoped private channels** for recruitment applicants ↔
authors and contribution NEEDS_CHANGES proposers ↔ curators.

**Scope sketch:**

- `dm_channels(id, scope, ref_id, party_a_id, party_b_id, status,
  closed_reason?)` UNIQUE on `(scope, ref_id, party_a_id, party_b_id)`.
- `dm_messages(id, channel_id FK CASCADE, sender_id, body,
  read_by_recipient_at?)`.
- Auto-close on workflow exit (recruitment FILLED/CLOSED, contribution
  APPROVED/REJECTED) plus 30-day grace.
- Per-message report → `Report.target_type = 'DM_MESSAGE'`.
- Mobile inbox `/me/dm` + entry-point button on recruitment detail +
  contribution curation detail.
- Auto-mod rule: identical DM body 3× → auto-hide.

**Risk:** closed channels are a moderation blind spot. Mitigation in
the plan: separate ops-dashboard card for DM report counts.

### 1.2 Curator profile / portfolio — P6.10 ✅ SHIPPED

`GET /v1/profiles/:userId/curator-portfolio` aggregates contributions
the user resolved (APPROVED only, so a later admin revert self-prunes
the entry), `reference_source_rules` they introduced, and P2.2
weighted-score. Mobile `CuratorPortfolioScreen` is gated to curator
roles. No new schema — entirely read-side.
See `apps/api/src/modules/user-profile/curator-portfolio.service.ts`.

### 1.3 Topic Hub Memory ("오늘의 기록") — P6.11 ✅ SHIPPED

`GET /v1/me/memories` returns 365/730d-ago anniversaries (RoomFollow,
APPROVED KnowledgeContribution, EventRsvp; SavedItem excluded),
accessPolicy-gated with HIDDEN/DELETED filtered out. Home "오늘의 기록"
card auto-hides on empty days. No new schema — pure query.
See `apps/api/src/modules/memories/memories.service.ts`.

### 1.4 Room roles — P6.12 ✅ SHIPPED (one follow-up remaining)

`room_roles` table + owner-only grant/revoke
(`POST`/`DELETE /v1/rooms/:slug/roles`) + `RoomRoleService.canModerateRoom`
(owner OR room-MODERATOR OR global MODERATOR/ADMIN). Mobile owner-only
`RoomModeratorsScreen` (nickname-search add + revoke) and a moderator
badge. Grant guards — no self-grant, role ∈ {MODERATOR, MEMBER}, target
ACTIVE, upsert un-revokes — are covered by `room-role.e2e-spec.ts`.
See `apps/api/src/modules/community/room-role.service.ts`.

**Remaining follow-up — `canModerateRoom` → report-resolve wiring
(plan-mode).** `canModerateRoom` exists but is not yet consumed by the
moderation hide path. `ReportService.resolve()`, `getDetail()`, and
`listQueue()` are all gated by the global `isModerator(viewer)` check,
and the report queue is global. Letting a room owner / delegated room
moderator resolve a POST/REPLY report **in their own room** requires
making that authorization room-aware across all three methods, plus a
room-scoped `GET /v1/rooms/:slug/reports` queue (a global queue would
leak other rooms' reports). This touches the app's most
security-sensitive authorization surface, so it is a deliberate
plan-mode change, not an auto-mode edit. Until it lands, delegated room
moderators can be granted/revoked but cannot yet action reports.

---

## 2. Mobile stabilization (improvement plan §2)

Defensive work to land alongside the next mobile release attempt.

| Item | Note |
|---|---|
| Scroll-aware visual smoke for `Home` / `Room` / `PostDetail` / `Profile` | Today only Sliver-based screens use `expectNoOverflowWhileScrolling`; ListView screens fall back to the simpler helper. Defensive. |
| Refresh `flutter analyze` / `flutter test` baselines in `MOBILE_BETA_GAP_AUDIT.md` §1.8 | Numeric counts in prior revisions predate Phase 1–6. |
| iOS scaffold (`apps/mobile/ios/`) | `flutter create --platforms=ios .` from a macOS host. Out of scope for Play Internal. Separate workstream once Android Beta is live. |

---

## 3. Topic Hub / Event UX (improvement plan §3)

Code surfaces exist; the work is to make them discoverable and
explainable.

| Item | Note |
|---|---|
| Topic Hub home — "이번 주 이 주제에서 바뀐 것" foreground | P2.4 digest is already computed; reorder the Topic Hub screen so the digest sits above "최근 토론". |
| Source-tier badge in Search results | P2.3 stores tier; surface it on `SearchResultsScreen` next to the reference card. |
| Event detail flow polish | RSVP → reminder → live → review → digest is all wired. UI should signal RSVP status, attended/not-yet-attended, live-window open/closed, and review-eligibility prerequisites in one card stack. |
| Mention / reaction / boost / poll / block / mute consistency pass | All Phase 6 surfaces exist; review Home / Room / Post / Profile for inconsistent affordances (e.g. action-bar ordering, long-press hint copy). |
| Share card + deep link surface review | P1.5 wires the routing; expand entry points on Topic Hub / Event / Profile detail screens. |

Explicit non-goal: NO For-You algorithm. The Home ranking remains
deterministic and explainable.

---

## 4. Operations + trust (improvement plan §4)

Make the safety nets observable.

| Item | Note |
|---|---|
| Auto-mod rule-hit card on Ops dashboard | Auto-mod (P5.2) records to analytics; surface "today's rule hits" + the 7d trend so operators can spot a calibration issue early. |
| Block/Mute moderation surface | `BlockMuteService` is in place; expose a "user got reported AND has N blocks in 24h" signal to admin for early intervention. |
| Cron health on `/admin/system-health` | The six cron handlers + advisory locks are in place; surface "last successful tick" + "last lock contention" per handler so multi-replica races are visible. |
| Rate-limit enforcement ramp-up | `RateLimitService` runs in shadow mode by default (P5.1). Plan: enable per-route enforcement in staged increments with the analytics surface to confirm no real-user collateral. |
| Admin web — DM moderation surface (depends on §1.1) | Specific to P6.9; the workflow-scoped DM moderation card the §1.1 risk mitigation calls for. |
| Notification grouping inspection | P6.3 grouping is in place; admin should be able to inspect a `(user, group_key)` row to see the `actors` array + drift. |

---

## 5. Smaller follow-ups

Items that don't justify their own section.

| Item | Notes |
|---|---|
| Trust-score ramp-up surfaces | `TrustScoreService` powers P5.1 + P5.2; the formula is centralized but not surfaced. Internal admin "this user's current tier" inspector would help moderation decisions. |
| Account deletion (GDPR / Korean PIPA) | Cascade-deletes work via Prisma `onDelete`, but no self-serve flow. |
| Soft-delete UI affordance for authors | The DB supports it; not every detail screen has a "삭제" entry point. |
| Reply depth > 2 | Today blocked at depth 3. Decide whether to extend or formalize. |
| Real-time updates | No WebSocket / SSE; clients poll on screen entry. |
| `auth.service.spec.ts` + `auth.e2e-spec.ts` coverage for email signup / refresh rotation / family revoke | P1.1 backend code is in place; the existing `auth.e2e-spec.ts` still focuses on the dev login path. Add cases for the email surface before opening signup in production. |
| Production email verification provider | Wired `IEmailDelivery` boundary; pick a provider once signup is opened beyond a closed cohort. |
| Password reset email flow | Drops out of #5 (email provider). |
| Search ranking refinement | pg_trgm landed (P2.5). Watch metrics; consider a Korean tokenizer / BM25 / vector if quality drifts. |
| Mention rate-limit telemetry | P6.1 enforces per-post cap 20; surface "mention spam attempts" on Ops dashboard. |
| Web bundle distribution | Web target works for local QA only ([LOCAL_BROWSER_QA.md](LOCAL_BROWSER_QA.md)); decide once mobile is live whether to invest in a web channel. |

---

## 6. Explicitly **not** in this backlog

The Phase 6 plan §"명시적 거부" + `MOBILE_BETA_GAP_AUDIT.md` §4 cover
the canonical rejected proposals. When someone asks "why isn't X
here?" — check those sections first.

Items frequently re-proposed:

- **Algorithmic For You feed** — deterministic ranking is the product
  position (`docs/00_PRISM_CLUB_BRIEF.md:14, 137-147`).
- **24h Stories** — P6.8 Event live mode covers the bounded use case.
- **Open 1:N group DM** — Room covers group conversation; §1.1 covers
  the workflow-scoped variant.
- **Reels / short video** — out of brand identity + infra cost.
- **Marketplace / payment** — PRISM Event handles checkout.
- **ActivityPub / Fediverse** — single-tenant Korean app.

If a new proposal lands here, it must explain how it differs from the
above, not why the user wants it.
