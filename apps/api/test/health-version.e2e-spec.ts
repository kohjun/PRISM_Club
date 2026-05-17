import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('Health version endpoint (e2e)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('GET /v1/health/version is public', async () => {
    const res = await request(ctx.app.getHttpServer()).get('/v1/health/version');
    expect(res.status).toBe(200);
  });

  test('GET /v1/health/version returns the expected shape with safe defaults', async () => {
    const res = await request(ctx.app.getHttpServer()).get('/v1/health/version');
    expect(res.status).toBe(200);
    expect(Object.keys(res.body).sort()).toEqual(
      [
        'app_version',
        'build_time',
        'git_sha',
        'node_env',
        'release_channel',
      ].sort(),
    );
    expect(typeof res.body.app_version).toBe('string');
    expect(typeof res.body.git_sha).toBe('string');
    expect(res.body.build_time === null || typeof res.body.build_time === 'string').toBe(true);
    expect(res.body.release_channel).toMatch(/^(local|staging|beta|production|unknown)$/);
    expect(typeof res.body.node_env).toBe('string');
  });

  test('GET /v1/health/version never echoes JWT_SECRET / DATABASE_URL values', async () => {
    const res = await request(ctx.app.getHttpServer()).get('/v1/health/version');
    const serialized = JSON.stringify(res.body);
    // Test env normally sets these to non-empty values; they MUST NOT
    // appear in the response.
    if (process.env.JWT_SECRET) {
      expect(serialized).not.toContain(process.env.JWT_SECRET);
    }
    if (process.env.DATABASE_URL) {
      expect(serialized).not.toContain(process.env.DATABASE_URL);
    }
  });

  test('GET /v1/health still returns the minimal shape (no version drift)', async () => {
    const res = await request(ctx.app.getHttpServer()).get('/v1/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ok: true });
  });
});
