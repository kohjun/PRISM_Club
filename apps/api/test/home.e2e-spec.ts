import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('Milestone 7 — home feed (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('GET /v1/home returns all 7 sections for minseo (has follows)', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get('/v1/home')
      .set(HEAD(ctx.uuids.user.minseo));

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      unread_notification_count: expect.any(Number),
      followed_room_updates: expect.any(Array),
      recommended_rooms: expect.any(Array),
      recommended_events: expect.any(Array),
      trending_posts: expect.any(Array),
      active_topic_hubs: expect.any(Array),
      saved_recently: expect.any(Array),
    });
    // minseo has 1 unread seeded notification
    expect(res.body.unread_notification_count).toBeGreaterThanOrEqual(1);
    // minseo follows 2 rooms, so should have followed_room_updates
    expect(res.body.followed_room_updates.length).toBeGreaterThanOrEqual(1);
  });

  test('GET /v1/home as joon (no follows) → followed_room_updates is empty', async () => {
    // joon has no seeded follows, so followed_room_updates should be empty
    const res = await request(ctx.app.getHttpServer())
      .get('/v1/home')
      .set(HEAD(ctx.uuids.user.joon));

    expect(res.status).toBe(200);
    expect(res.body.followed_room_updates).toEqual([]);
  });

  test('GET /v1/home/feed returns items array with type and reason fields', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get('/v1/home/feed')
      .set(HEAD(ctx.uuids.user.minseo));

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      items: expect.any(Array),
    });
    expect('next_cursor' in res.body).toBe(true);
    if (res.body.items.length > 0) {
      const item = res.body.items[0];
      expect(item).toMatchObject({
        id: expect.any(String),
        type: expect.any(String),
        reason: expect.any(String),
        payload: expect.any(Object),
      });
    }
  });
});
