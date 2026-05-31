import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

/**
 * P6.12 completion — delegated room moderation on the report-resolve path.
 *
 * Authorization is strictly ADDITIVE on top of the global moderator
 * gate: a room owner or a delegated room MODERATOR may resolve a
 * POST/REPLY report whose target lives in THEIR room, and may read a
 * room-scoped report queue. The room is always derived from the report
 * target, so a room moderator can never reach another room's content —
 * the cross-room test below is the core isolation guarantee.
 *
 * Seed facts used:
 *   - `swap-style-talk-game` is a USER room owned by haneul.
 *   - haneulIdea + haneulTalkRoundPreview are posts in that room.
 *   - minseoReview is a post in `dating-event-reviews` (a different room
 *     haneul neither owns nor moderates).
 *   - coral carries a global moderator role (see moderation.e2e-spec).
 */
describe('P6.12 — room-scoped report moderation (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });
  const ROOM = 'swap-style-talk-game';

  const report = (reporterId: string, targetId: string) =>
    request(ctx.app.getHttpServer())
      .post('/v1/reports')
      .set(HEAD(reporterId))
      .send({ target_type: 'POST', target_id: targetId, reason: 'spam' });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('room-scoped queue returns only this room\'s OPEN reports; non-mod 403; unknown room 404', async () => {
    const server = ctx.app.getHttpServer();

    // One OPEN report in haneul's room, one in a different room.
    const inRoom = await report(ctx.uuids.user.studio_lead, ctx.uuids.post.haneulIdea);
    expect(inRoom.status).toBe(201);
    const otherRoom = await report(ctx.uuids.user.joon, ctx.uuids.post.minseoReview);
    expect(otherRoom.status).toBe(201);

    // Owner sees only their room's report, never the other room's.
    const queue = await request(server)
      .get(`/v1/rooms/${ROOM}/reports`)
      .set(HEAD(ctx.uuids.user.haneul));
    expect(queue.status).toBe(200);
    const ids = (queue.body.items as Array<{ id: string }>).map((r) => r.id);
    expect(ids).toContain(inRoom.body.id);
    expect(ids).not.toContain(otherRoom.body.id);

    // A plain member of the room cannot read the moderation queue.
    const denied = await request(server)
      .get(`/v1/rooms/${ROOM}/reports`)
      .set(HEAD(ctx.uuids.user.joon));
    expect(denied.status).toBe(403);

    // Unknown room → 404.
    const missing = await request(server)
      .get('/v1/rooms/no-such-room/reports')
      .set(HEAD(ctx.uuids.user.haneul));
    expect(missing.status).toBe(404);
  });

  test('room owner (not a global mod) can resolve an in-room report', async () => {
    const server = ctx.app.getHttpServer();
    const created = await report(ctx.uuids.user.studio_mate, ctx.uuids.post.haneulIdea);
    expect(created.status).toBe(201);

    const resolved = await request(server)
      .post(`/v1/admin/reports/${created.body.id}/resolve`)
      .set(HEAD(ctx.uuids.user.haneul))
      .send({ action: 'DISMISS', note: 'owner reviewed' });
    expect(resolved.status).toBe(201);
    expect(resolved.body.resolution).toBe('DISMISSED');
  });

  test('room owner CANNOT resolve a report in a room they do not moderate (cross-room isolation)', async () => {
    const server = ctx.app.getHttpServer();
    const created = await report(ctx.uuids.user.minseo, ctx.uuids.post.minseoReview);
    expect(created.status).toBe(201);

    // haneul owns swap-style-talk-game but neither owns nor moderates
    // dating-event-reviews, and is not a global moderator → 403.
    const denied = await request(server)
      .post(`/v1/admin/reports/${created.body.id}/resolve`)
      .set(HEAD(ctx.uuids.user.haneul))
      .send({ action: 'HIDE', note: 'should be blocked' });
    expect(denied.status).toBe(403);

    // The global moderator path is unchanged — coral resolves it.
    const allowed = await request(server)
      .post(`/v1/admin/reports/${created.body.id}/resolve`)
      .set(HEAD(ctx.uuids.user.coral))
      .send({ action: 'DISMISS', note: 'global mod' });
    expect(allowed.status).toBe(201);
    expect(allowed.body.resolution).toBe('DISMISSED');
  });

  test('a delegated room MODERATOR can resolve in-room; a plain member cannot', async () => {
    const server = ctx.app.getHttpServer();
    const created = await report(ctx.uuids.user.joon, ctx.uuids.post.haneulTalkRoundPreview);
    expect(created.status).toBe(201);

    // Before the grant, minseo is a plain member → 403.
    const before = await request(server)
      .post(`/v1/admin/reports/${created.body.id}/resolve`)
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ action: 'HIDE' });
    expect(before.status).toBe(403);

    // Owner delegates a room MODERATOR role to minseo.
    const grant = await request(server)
      .post(`/v1/rooms/${ROOM}/roles`)
      .set(HEAD(ctx.uuids.user.haneul))
      .send({ user_id: ctx.uuids.user.minseo, role: 'MODERATOR' });
    expect(grant.status).toBe(200);

    // Now the same member can resolve the in-room report.
    const after = await request(server)
      .post(`/v1/admin/reports/${created.body.id}/resolve`)
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ action: 'HIDE', note: 'delegated mod' });
    expect(after.status).toBe(201);
    expect(after.body.resolution).toBe('HIDDEN');

    // The delegated role does NOT extend to another room's report.
    const otherRoomReport = await report(
      ctx.uuids.user.studio_lead,
      ctx.uuids.post.minseoReview,
    );
    expect(otherRoomReport.status).toBe(201);
    const crossDenied = await request(server)
      .post(`/v1/admin/reports/${otherRoomReport.body.id}/resolve`)
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ action: 'HIDE' });
    expect(crossDenied.status).toBe(403);
  });
});
