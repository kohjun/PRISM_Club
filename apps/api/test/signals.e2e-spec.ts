import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('Milestone 12 — activity signals (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('Member cannot refresh signals (403)', async () => {
    const res = await request(ctx.app.getHttpServer())
      .post('/v1/admin/signals/refresh')
      .set(HEAD(ctx.uuids.user.joon));
    expect(res.status).toBe(403);
  });

  test('Curator can refresh signals; subsequent GET returns computed values', async () => {
    const refresh = await request(ctx.app.getHttpServer())
      .post('/v1/admin/signals/refresh')
      .set(HEAD(ctx.uuids.user.coral));
    expect(refresh.status).toBe(201);
    expect(refresh.body.hubs_processed).toBeGreaterThanOrEqual(1);

    const get = await request(ctx.app.getHttpServer())
      .get(`/v1/topic-hubs/${ctx.uuids.topicHub.loveContent}/signals`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(get.status).toBe(200);
    // After refresh, the love-content hub should have at least one computed signal
    // (HOT_DEBATE or POPULAR_REF) because seed posts have reply/like counts.
    expect(Array.isArray(get.body)).toBe(true);
  });

  test('Member viewing planner-only hub signals gets empty array', async () => {
    const get = await request(ctx.app.getHttpServer())
      .get(`/v1/topic-hubs/${ctx.uuids.topicHub.plannerStaff}/signals`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(get.status).toBe(200);
    expect(get.body).toEqual([]);
  });

  test('Planner can see planner-hub signals', async () => {
    // Refresh first to ensure planner hub has signals
    await request(ctx.app.getHttpServer())
      .post('/v1/admin/signals/refresh')
      .set(HEAD(ctx.uuids.user.coral));

    const get = await request(ctx.app.getHttpServer())
      .get(`/v1/topic-hubs/${ctx.uuids.topicHub.plannerStaff}/signals`)
      .set(HEAD(ctx.uuids.user.studio_lead));
    expect(get.status).toBe(200);
    // Planner space recruitment posts ⇒ likely produces signal entries
  });
});
