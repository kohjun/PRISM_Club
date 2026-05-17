import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('Milestone 9 — moderation + reports (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('Full report → moderate → hide flow excludes content from read surfaces', async () => {
    const server = ctx.app.getHttpServer();

    // 1. Member (joon) reports minseo's review post
    const create = await request(server)
      .post('/v1/reports')
      .set(HEAD(ctx.uuids.user.joon))
      .send({
        target_type: 'POST',
        target_id: ctx.uuids.post.minseoReview,
        reason: 'spam',
      });
    expect(create.status).toBe(201);
    expect(create.body.status).toBe('OPEN');
    const reportId = create.body.id;

    // 2. Member sees their report in /me/reports
    const mine = await request(server)
      .get('/v1/me/reports')
      .set(HEAD(ctx.uuids.user.joon));
    expect(mine.status).toBe(200);
    expect(mine.body.items.length).toBeGreaterThanOrEqual(1);

    // 3. Non-moderator gets 403 on /admin/reports
    const denied = await request(server)
      .get('/v1/admin/reports')
      .set(HEAD(ctx.uuids.user.joon));
    expect(denied.status).toBe(403);

    // 4. Moderator (coral) sees the queue
    const queue = await request(server)
      .get('/v1/admin/reports')
      .set(HEAD(ctx.uuids.user.coral));
    expect(queue.status).toBe(200);
    expect(queue.body.items.some((r: { id: string }) => r.id === reportId)).toBe(
      true,
    );

    // 5. Moderator hides the post
    const resolve = await request(server)
      .post(`/v1/admin/reports/${reportId}/resolve`)
      .set(HEAD(ctx.uuids.user.coral))
      .send({ action: 'HIDE', note: 'spam confirmed' });
    expect(resolve.status).toBe(201);
    expect(resolve.body.resolution).toBe('HIDDEN');

    // 6. Post should no longer appear in the room timeline
    const room = await request(server)
      .get('/v1/rooms/dating-event-reviews/timeline')
      .set(HEAD(ctx.uuids.user.joon));
    expect(room.status).toBe(200);
    const ids = room.body.items.map((p: { id: string }) => p.id);
    expect(ids).not.toContain(ctx.uuids.post.minseoReview);

    // 7. Post should no longer appear in search results
    const search = await request(server)
      .get('/v1/search?q=후기')
      .set(HEAD(ctx.uuids.user.joon));
    expect(search.status).toBe(200);
    const postGroup = (search.body.groups as Array<{ type: string; items: Array<{ id: string }> }>)
      .find((g) => g.type === 'post');
    const searchPostIds = postGroup?.items.map((h) => h.id) ?? [];
    expect(searchPostIds).not.toContain(ctx.uuids.post.minseoReview);
  });
});
