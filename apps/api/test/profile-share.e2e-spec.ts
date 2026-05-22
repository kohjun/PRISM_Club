import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

/**
 * P4.1 — profile share card + OG PNG (e2e)
 *
 * Both endpoints are public so a messaging app (KakaoTalk, Slack)
 * can render the preview without auth. We verify:
 *   - share-card returns nickname + TIER badge for an ACTIVE user
 *   - share-card 404s for unknown / DELETED-equivalent users
 *   - OG PNG returns image/png bytes with a long cache header
 *   - PROFILE_SHARED analytics row is emitted per share-card hit
 */
describe('P4.1 — profile share card (e2e)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  beforeEach(async () => {
    await ctx.prisma.analyticsEvent.deleteMany({
      where: { eventType: 'PROFILE_SHARED' },
    });
  });

  test('GET /v1/profiles/:id/share-card returns title + TIER badge', async () => {
    const res = await request(ctx.app.getHttpServer()).get(
      `/v1/profiles/${ctx.uuids.user.minseo}/share-card`,
    );
    expect(res.status).toBe(200);
    expect(res.body.user_id).toBe(ctx.uuids.user.minseo);
    expect(typeof res.body.title).toBe('string');
    expect(res.body.title.length).toBeGreaterThan(0);
    expect(res.body.deep_link).toContain('/share/profile/');
    expect(res.body.og_image_url).toContain('/v1/og/profile/');
    expect(Array.isArray(res.body.badges)).toBe(true);
    expect(res.body.badges[0].kind).toBe('TIER');
  });

  test('GET /v1/profiles/:id/share-card 404s for unknown user', async () => {
    const res = await request(ctx.app.getHttpServer()).get(
      '/v1/profiles/00000000-0000-0000-0000-000000000000/share-card',
    );
    expect(res.status).toBe(404);
  });

  test('GET /v1/og/profile/:id.png returns image/png with long cache', async () => {
    const res = await request(ctx.app.getHttpServer()).get(
      `/v1/og/profile/${ctx.uuids.user.minseo}.png`,
    );
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/^image\/png/);
    expect(res.headers['cache-control']).toContain('public');
    expect(res.headers['cache-control']).toContain('max-age=');
    // PNG magic header — first 4 bytes are 89 50 4E 47.
    expect(res.body.slice(0, 4).toString('hex')).toBe('89504e47');
  });

  test('OG PNG endpoint 404s for unknown user', async () => {
    const res = await request(ctx.app.getHttpServer()).get(
      '/v1/og/profile/00000000-0000-0000-0000-000000000000.png',
    );
    expect(res.status).toBe(404);
  });

  test('share-card hit emits a PROFILE_SHARED analytics row', async () => {
    await request(ctx.app.getHttpServer()).get(
      `/v1/profiles/${ctx.uuids.user.joon}/share-card`,
    );
    // analytics is fire-and-forget, give the queue a tick.
    await new Promise((r) => setTimeout(r, 80));
    const rows = await ctx.prisma.analyticsEvent.findMany({
      where: { eventType: 'PROFILE_SHARED' },
    });
    expect(rows.length).toBeGreaterThanOrEqual(1);
    const payload = rows[0].payload as Record<string, unknown> | null;
    expect(payload).not.toBeNull();
    expect(payload!['target_user_id']).toBe(ctx.uuids.user.joon);
  });
});
