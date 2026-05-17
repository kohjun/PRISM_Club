import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

/**
 * M19 — analytics events pipeline (e2e)
 *
 * Verifies that representative server actions emit AnalyticsEvent rows and
 * that the admin summary endpoint is properly role-gated.
 */
describe('Milestone 19 — analytics events (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  beforeEach(async () => {
    await ctx.prisma.analyticsEvent.deleteMany({});
  });

  test('POST /v1/auth/login records AUTH_LOGIN', async () => {
    const res = await request(ctx.app.getHttpServer())
      .post('/v1/auth/login')
      .send({ user_id: ctx.uuids.user.minseo });
    expect([200, 201]).toContain(res.status);

    // Fire-and-forget — allow flush
    await new Promise((r) => setTimeout(r, 80));
    const rows = await ctx.prisma.analyticsEvent.findMany({
      where: { eventType: 'AUTH_LOGIN' },
    });
    expect(rows.length).toBe(1);
    expect(rows[0].actorId).toBe(ctx.uuids.user.minseo);
  });

  test('POST /v1/rooms/:slug/posts records POST_CREATED', async () => {
    const res = await request(ctx.app.getHttpServer())
      .post('/v1/rooms/dating-event-reviews/posts')
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ body: 'analytics test post' });
    expect(res.status).toBe(201);

    await new Promise((r) => setTimeout(r, 80));
    const rows = await ctx.prisma.analyticsEvent.findMany({
      where: { eventType: 'POST_CREATED' },
    });
    expect(rows.length).toBe(1);
    const p = rows[0].payload as Record<string, unknown>;
    expect(p.room_slug).toBe('dating-event-reviews');
    expect(p.post_type).toBe('GENERAL');
    // body content MUST NOT appear in analytics
    expect((p as Record<string, unknown>).body).toBeUndefined();
  });

  test('POST /v1/rooms/:slug/follow records ROOM_FOLLOWED then ROOM_UNFOLLOWED', async () => {
    const server = ctx.app.getHttpServer();

    const follow = await request(server)
      .post('/v1/rooms/swap-style-talk-game/follow')
      .set(HEAD(ctx.uuids.user.joon));
    expect(follow.status).toBe(200);

    const unfollow = await request(server)
      .post('/v1/rooms/swap-style-talk-game/follow')
      .set(HEAD(ctx.uuids.user.joon));
    expect(unfollow.status).toBe(200);

    await new Promise((r) => setTimeout(r, 80));

    const followed = await ctx.prisma.analyticsEvent.findFirst({
      where: { eventType: 'ROOM_FOLLOWED', actorId: ctx.uuids.user.joon },
    });
    const unfollowed = await ctx.prisma.analyticsEvent.findFirst({
      where: { eventType: 'ROOM_UNFOLLOWED', actorId: ctx.uuids.user.joon },
    });
    expect(followed).toBeTruthy();
    expect(unfollowed).toBeTruthy();
  });

  test('GET /v1/admin/analytics/summary requires CURATOR/MODERATOR/ADMIN', async () => {
    const server = ctx.app.getHttpServer();

    // Member is rejected
    const memberRes = await request(server)
      .get('/v1/admin/analytics/summary')
      .set(HEAD(ctx.uuids.user.joon));
    expect(memberRes.status).toBe(403);

    // Curator passes
    const curatorRes = await request(server)
      .get('/v1/admin/analytics/summary')
      .set(HEAD(ctx.uuids.user.coral));
    expect(curatorRes.status).toBe(200);
    expect(curatorRes.body).toMatchObject({
      window_days: 30,
      counts: expect.any(Array),
    });
  });

  test('summary counts reflect events written during the test', async () => {
    const server = ctx.app.getHttpServer();

    // Generate two AUTH_LOGIN + one POST_CREATED
    await request(server)
      .post('/v1/auth/login')
      .send({ user_id: ctx.uuids.user.minseo });
    await request(server)
      .post('/v1/auth/login')
      .send({ user_id: ctx.uuids.user.joon });
    await request(server)
      .post('/v1/rooms/dating-event-reviews/posts')
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ body: 'another analytics post' });

    await new Promise((r) => setTimeout(r, 100));

    const res = await request(server)
      .get('/v1/admin/analytics/summary')
      .set(HEAD(ctx.uuids.user.coral));
    expect(res.status).toBe(200);
    const counts = res.body.counts as Array<{ event_type: string; count: number }>;
    const login = counts.find((c) => c.event_type === 'AUTH_LOGIN');
    const post = counts.find((c) => c.event_type === 'POST_CREATED');
    expect(login?.count ?? 0).toBeGreaterThanOrEqual(2);
    expect(post?.count ?? 0).toBeGreaterThanOrEqual(1);
  });
});
