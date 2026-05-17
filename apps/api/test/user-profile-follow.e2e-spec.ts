import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('Milestone 8 — user profiles + follow (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('Member viewing studio_lead profile: no recruitment posts in recent_posts', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get(`/v1/users/${ctx.uuids.user.studio_lead}/profile`)
      .set(HEAD(ctx.uuids.user.minseo));

    expect(res.status).toBe(200);
    expect(res.body.user.nickname).toBe('studio_lead');
    expect(res.body.recent_posts).toEqual([]);
    expect(res.body.counts.post_count).toBe(0);
    expect(res.body.roles).toContain('VERIFIED_PLANNER');
  });

  test('Planner viewing same profile: recruitment posts visible', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get(`/v1/users/${ctx.uuids.user.studio_lead}/profile`)
      .set(HEAD(ctx.uuids.user.studio_mate));

    expect(res.status).toBe(200);
    expect(res.body.recent_posts.length).toBeGreaterThanOrEqual(1);
    expect(res.body.counts.post_count).toBeGreaterThanOrEqual(1);
  });

  test('Follow toggle round-trip', async () => {
    const server = ctx.app.getHttpServer();
    // haneul → coral is NOT in seed; clean starting point.
    const target = ctx.uuids.user.coral;
    const me = ctx.uuids.user.haneul;

    const t1 = await request(server)
      .post(`/v1/users/${target}/follow-toggle`)
      .set(HEAD(me));
    expect(t1.status).toBe(201);
    expect(t1.body.followed).toBe(true);

    const t2 = await request(server)
      .post(`/v1/users/${target}/follow-toggle`)
      .set(HEAD(me));
    expect(t2.body.followed).toBe(false);

    const state = await request(server)
      .get(`/v1/users/${target}/follow-state`)
      .set(HEAD(me));
    expect(state.body.followed).toBe(false);
  });

  test('PATCH /me/profile updates bio + interests', async () => {
    const server = ctx.app.getHttpServer();
    const res = await request(server)
      .patch('/v1/me/profile')
      .set(HEAD(ctx.uuids.user.joon))
      .send({ bio: 'updated bio', interests: ['Festival', 'festival', 'Q&A'] });
    expect(res.status).toBe(200);
    expect(res.body.bio).toBe('updated bio');
    expect(res.body.interests).toEqual(['festival', 'q&a']);

    // Verify by fetching the profile
    const fetch = await request(server)
      .get(`/v1/users/${ctx.uuids.user.joon}/profile`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(fetch.body.profile.bio).toBe('updated bio');
    expect(fetch.body.profile.interests).toEqual(['festival', 'q&a']);
  });
});
