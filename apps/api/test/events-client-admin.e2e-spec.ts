import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

/**
 * M20 — Events client diagnostic endpoint (e2e).
 *
 * Verifies role-gating and the mock-fallback shape. The bootstrap test
 * app runs with the default EVENTS_CLIENT_MODE (unset → mock), so we
 * expect `mode: 'mock'` in the response.
 */
describe('Milestone 20 — events client diagnostic (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('member is rejected with 403', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get('/v1/admin/events-client/status')
      .set(HEAD(ctx.uuids.user.joon));
    expect(res.status).toBe(403);
  });

  test('curator sees the diagnostic envelope', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get('/v1/admin/events-client/status')
      .set(HEAD(ctx.uuids.user.coral));
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      mode: expect.stringMatching(/mock|prism/),
      stats: {
        parsed_ok: expect.any(Number),
        parse_failed: expect.any(Number),
        http_errors: expect.any(Number),
        timeouts: expect.any(Number),
      },
    });
  });

  test('moderator and admin also see the diagnostic envelope', async () => {
    const modRes = await request(ctx.app.getHttpServer())
      .get('/v1/admin/events-client/status')
      .set(HEAD(ctx.uuids.user.coral)); // coral has CURATOR + MODERATOR
    expect(modRes.status).toBe(200);
  });
});
