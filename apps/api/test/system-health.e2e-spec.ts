import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

const HEAD = (userId: string) => ({ 'X-User-Id': userId });

/**
 * P5.6 — system health snapshot (e2e)
 *
 * Confirms the admin-only gate and that the snapshot has a `metrics`
 * array with the curated keys present even at idle (count=0). Also
 * runs a real search so `search.latency_ms` increments at least once
 * to prove the recorder is wired.
 */
describe('P5.6 — system health (e2e)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('member -> 403', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get('/v1/admin/system-health')
      .set(HEAD(ctx.uuids.user.joon));
    expect(res.status).toBe(403);
  });

  test('curator -> 200 with metrics array of curated keys', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get('/v1/admin/system-health')
      .set(HEAD(ctx.uuids.user.coral));
    expect(res.status).toBe(200);
    expect(typeof res.body.generated_at).toBe('string');
    expect(Array.isArray(res.body.metrics)).toBe(true);
    const keys = (res.body.metrics as { key: string }[]).map((m) => m.key);
    // The curated list lives in system-health.controller.ts. Verify a
    // few load-bearing entries are present even when traffic hasn't
    // exercised them yet.
    expect(keys).toEqual(
      expect.arrayContaining([
        'search.latency_ms',
        'media.upload.success',
        'notification.push.sent',
      ]),
    );
  });

  test('search activity bumps search.latency_ms count_1h', async () => {
    // Snapshot before
    const before = await request(ctx.app.getHttpServer())
      .get('/v1/admin/system-health')
      .set(HEAD(ctx.uuids.user.coral));
    const beforeCount =
      (before.body.metrics as { key: string; count_1h: number }[]).find(
        (m) => m.key === 'search.latency_ms',
      )?.count_1h ?? 0;

    // Drive a search.
    const search = await request(ctx.app.getHttpServer())
      .get('/v1/search?q=test')
      .set(HEAD(ctx.uuids.user.minseo));
    expect([200, 400]).toContain(search.status);

    const after = await request(ctx.app.getHttpServer())
      .get('/v1/admin/system-health')
      .set(HEAD(ctx.uuids.user.coral));
    const afterCount =
      (after.body.metrics as { key: string; count_1h: number }[]).find(
        (m) => m.key === 'search.latency_ms',
      )?.count_1h ?? 0;

    expect(afterCount).toBeGreaterThan(beforeCount);
  });
});
