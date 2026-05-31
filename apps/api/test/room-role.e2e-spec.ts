import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('P6.12 — room roles (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  // Seed: swap-style-talk-game is a USER room owned by haneul.
  const ROOM = 'swap-style-talk-game';

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('owner can grant a room MODERATOR and it shows in the roster', async () => {
    const server = ctx.app.getHttpServer();
    const grant = await request(server)
      .post(`/v1/rooms/${ROOM}/roles`)
      .set(HEAD(ctx.uuids.user.haneul))
      .send({ user_id: ctx.uuids.user.minseo, role: 'MODERATOR' });
    expect(grant.status).toBe(200);
    expect(grant.body.user_id).toBe(ctx.uuids.user.minseo);
    expect(grant.body.role).toBe('MODERATOR');

    const list = await request(server)
      .get(`/v1/rooms/${ROOM}/roles`)
      .set(HEAD(ctx.uuids.user.haneul));
    expect(list.status).toBe(200);
    expect(
      (list.body as Array<{ user_id: string }>).some(
        (r) => r.user_id === ctx.uuids.user.minseo,
      ),
    ).toBe(true);
  });

  test('granting is idempotent (re-grant un-revokes, single row)', async () => {
    const server = ctx.app.getHttpServer();
    await request(server)
      .post(`/v1/rooms/${ROOM}/roles`)
      .set(HEAD(ctx.uuids.user.haneul))
      .send({ user_id: ctx.uuids.user.minseo, role: 'MODERATOR' });
    const count = await ctx.prisma.roomRole.count({
      where: {
        room: { slug: ROOM },
        userId: ctx.uuids.user.minseo,
      },
    });
    expect(count).toBe(1);
  });

  test('a non-owner cannot grant (escalation guard) → 403', async () => {
    // minseo is a room moderator now (from test 1) but NOT the owner —
    // a room moderator must not be able to mint more moderators.
    const res = await request(ctx.app.getHttpServer())
      .post(`/v1/rooms/${ROOM}/roles`)
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ user_id: ctx.uuids.user.joon, role: 'MODERATOR' });
    expect(res.status).toBe(403);
  });

  test('owner cannot grant to themselves → 400', async () => {
    const res = await request(ctx.app.getHttpServer())
      .post(`/v1/rooms/${ROOM}/roles`)
      .set(HEAD(ctx.uuids.user.haneul))
      .send({ user_id: ctx.uuids.user.haneul, role: 'MODERATOR' });
    expect(res.status).toBe(400);
  });

  test('invalid role → 400', async () => {
    const res = await request(ctx.app.getHttpServer())
      .post(`/v1/rooms/${ROOM}/roles`)
      .set(HEAD(ctx.uuids.user.haneul))
      .send({ user_id: ctx.uuids.user.joon, role: 'ADMIN' });
    expect(res.status).toBe(400);
  });

  test('owner can revoke; the member drops out of the roster', async () => {
    const server = ctx.app.getHttpServer();
    const del = await request(server)
      .delete(`/v1/rooms/${ROOM}/roles/${ctx.uuids.user.minseo}`)
      .set(HEAD(ctx.uuids.user.haneul));
    expect(del.status).toBe(200);

    const list = await request(server)
      .get(`/v1/rooms/${ROOM}/roles`)
      .set(HEAD(ctx.uuids.user.haneul));
    expect(
      (list.body as Array<{ user_id: string }>).some(
        (r) => r.user_id === ctx.uuids.user.minseo,
      ),
    ).toBe(false);
  });

  test('unknown room → 404', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get('/v1/rooms/no-such-room/roles')
      .set(HEAD(ctx.uuids.user.haneul));
    expect(res.status).toBe(404);
  });
});
