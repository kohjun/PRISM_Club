import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('Milestone 6 — follow / save / notification (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  describe('Follows', () => {
    test('POST follow toggle → follow and unfollow round trip', async () => {
      const server = ctx.app.getHttpServer();

      // joon follows swap-style-talk-game (not seeded as a follower)
      const follow = await request(server)
        .post('/v1/rooms/swap-style-talk-game/follow')
        .set(HEAD(ctx.uuids.user.joon));
      expect(follow.status).toBe(200);
      expect(follow.body.followed).toBe(true);
      expect(follow.body.follower_count).toBeGreaterThanOrEqual(1);

      // Toggle again → unfollow
      const unfollow = await request(server)
        .post('/v1/rooms/swap-style-talk-game/follow')
        .set(HEAD(ctx.uuids.user.joon));
      expect(unfollow.status).toBe(200);
      expect(unfollow.body.followed).toBe(false);
    });

    test('GET follow state reflects seeded follow for minseo', async () => {
      const server = ctx.app.getHttpServer();
      const state = await request(server)
        .get('/v1/rooms/dating-event-reviews/follow')
        .set(HEAD(ctx.uuids.user.minseo));
      expect(state.status).toBe(200);
      expect(state.body.followed).toBe(true);
    });
  });

  describe('Notifications', () => {
    test('minseo has seeded unread notification; mark all read → count = 0', async () => {
      const server = ctx.app.getHttpServer();

      // Seeded: 1 unread REPLY_ON_POST
      const unreadBefore = await request(server)
        .get('/v1/me/notifications/unread-count')
        .set(HEAD(ctx.uuids.user.minseo));
      expect(unreadBefore.status).toBe(200);
      expect(unreadBefore.body.count).toBeGreaterThanOrEqual(1);

      // Mark all read
      const readAll = await request(server)
        .post('/v1/me/notifications/read-all')
        .set(HEAD(ctx.uuids.user.minseo));
      expect(readAll.status).toBe(200);
      expect(readAll.body.updated_count).toBeGreaterThanOrEqual(1);

      // Count should now be 0
      const unreadAfter = await request(server)
        .get('/v1/me/notifications/unread-count')
        .set(HEAD(ctx.uuids.user.minseo));
      expect(unreadAfter.body.count).toBe(0);
    });

    test('new post in followed room emits NEW_POST_IN_FOLLOWED_ROOM notification', async () => {
      const server = ctx.app.getHttpServer();

      // minseo follows dating-event-reviews (seeded); joon posts there
      const create = await request(server)
        .post('/v1/rooms/dating-event-reviews/posts')
        .set(HEAD(ctx.uuids.user.joon))
        .send({ body: 'e2e follow-notification test post' });
      expect(create.status).toBe(201);

      // minseo should have a NEW_POST_IN_FOLLOWED_ROOM notification
      const notifs = await request(server)
        .get('/v1/me/notifications')
        .set(HEAD(ctx.uuids.user.minseo));
      expect(notifs.status).toBe(200);
      const followNotif = notifs.body.items.find(
        (n: any) => n.type === 'NEW_POST_IN_FOLLOWED_ROOM' &&
          n.payload.postId === create.body.id,
      );
      expect(followNotif).toBeDefined();
    });
  });
});
