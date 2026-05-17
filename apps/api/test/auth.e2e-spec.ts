import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('Milestone 13 — auth (e2e)', () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('POST /v1/auth/login returns access_token + session', async () => {
    const res = await request(ctx.app.getHttpServer())
      .post('/v1/auth/login')
      .send({ user_id: ctx.uuids.user.minseo });
    expect(res.status).toBe(200);
    expect(res.body.access_token).toBeTruthy();
    expect(res.body.session.user_id).toBe(ctx.uuids.user.minseo);
    expect(res.body.session.nickname).toBe('민서');
    expect(Array.isArray(res.body.session.roles)).toBe(true);
  });

  test('Bearer token authenticates a protected endpoint (GET /v1/me)', async () => {
    const login = await request(ctx.app.getHttpServer())
      .post('/v1/auth/login')
      .send({ user_id: ctx.uuids.user.coral });
    const token = login.body.access_token as string;

    const res = await request(ctx.app.getHttpServer())
      .get('/v1/me')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(ctx.uuids.user.coral);
    // coral has CURATOR + MODERATOR roles in seed
    expect(res.body.roles).toEqual(
      expect.arrayContaining(['CURATOR', 'MODERATOR']),
    );
  });

  test('Bearer token role-gated: curator hits /admin/reports OK', async () => {
    const login = await request(ctx.app.getHttpServer())
      .post('/v1/auth/login')
      .send({ user_id: ctx.uuids.user.coral });
    const token = login.body.access_token as string;

    const res = await request(ctx.app.getHttpServer())
      .get('/v1/admin/reports')
      .set('Authorization', `Bearer ${token}`);
    // coral has MODERATOR -> moderator queue is accessible
    expect(res.status).toBe(200);
  });

  test('Invalid token returns 401', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get('/v1/me')
      .set('Authorization', 'Bearer not-a-real-token');
    expect(res.status).toBe(401);
  });

  test('Login with unknown user id returns 401', async () => {
    const res = await request(ctx.app.getHttpServer())
      .post('/v1/auth/login')
      .send({ user_id: '00000000-0000-0000-0000-000000000000' });
    expect(res.status).toBe(401);
  });

  test('GET /v1/auth/session returns current session', async () => {
    const login = await request(ctx.app.getHttpServer())
      .post('/v1/auth/login')
      .send({ user_id: ctx.uuids.user.haneul });
    const token = login.body.access_token as string;

    const res = await request(ctx.app.getHttpServer())
      .get('/v1/auth/session')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.user_id).toBe(ctx.uuids.user.haneul);
  });

  test('X-User-Id still works in dev mode (backward compat for tests/smoke)', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get('/v1/me')
      .set('X-User-Id', ctx.uuids.user.minseo);
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(ctx.uuids.user.minseo);
  });
});
