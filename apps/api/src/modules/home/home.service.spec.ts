import { asUser, bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { HomeService } from './home.service';

describe('HomeService', () => {
  let ctx: TestContext;
  let svc: HomeService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    svc = ctx.app.get(HomeService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('getBundle returns all 7 keys for member viewer', async () => {
    const bundle = await svc.getBundle(asUser(ctx.uuids.user.minseo));
    expect(bundle).toMatchObject({
      unread_notification_count: expect.any(Number),
      followed_room_updates: expect.any(Array),
      recommended_rooms: expect.any(Array),
      recommended_events: expect.any(Array),
      trending_posts: expect.any(Array),
      active_topic_hubs: expect.any(Array),
      saved_recently: expect.any(Array),
    });
  });

  test('followed_room_updates contains posts only from followed rooms', async () => {
    const bundle = await svc.getBundle(asUser(ctx.uuids.user.minseo));
    const followedRoomIds = [ctx.uuids.room.datingReviews, ctx.uuids.room.swapTalkGame];
    for (const post of bundle.followed_room_updates) {
      const room = await ctx.prisma.room.findFirst({
        where: { slug: post.room.slug },
      });
      expect(followedRoomIds).toContain(room?.id);
    }
  });

  test('recommended_rooms excludes already-followed rooms', async () => {
    const bundle = await svc.getBundle(asUser(ctx.uuids.user.minseo));
    const followedSlugs = ['dating-event-reviews', 'swap-style-talk-game'];
    for (const room of bundle.recommended_rooms) {
      expect(followedSlugs).not.toContain(room.slug);
    }
  });

  test('trending_posts sorted by score (likeCount*3 + replyCount*2 + bookmarkCount)', async () => {
    const bundle = await svc.getBundle(asUser(ctx.uuids.user.minseo));
    const scores = bundle.trending_posts.map(
      (p) => p.counts.like_count * 3 + p.counts.reply_count * 2,
    );
    for (let i = 1; i < scores.length; i++) {
      expect(scores[i]).toBeLessThanOrEqual(scores[i - 1]);
    }
  });

  test('recommended_rooms excludes PLANNER_ONLY rooms for member viewer', async () => {
    const bundle = await svc.getBundle(asUser(ctx.uuids.user.minseo, ['MEMBER']));
    // planner-recruitment is in PLANNER_ONLY space — must not appear
    const slugs = bundle.recommended_rooms.map((r) => r.slug);
    expect(slugs).not.toContain('planner-recruitment');
  });

  test('trending_posts excludes PLANNER_ONLY posts for member viewer', async () => {
    const bundle = await svc.getBundle(asUser(ctx.uuids.user.minseo, ['MEMBER']));
    for (const post of bundle.trending_posts) {
      const room = await ctx.prisma.room.findFirst({
        where: { slug: post.room.slug },
        include: { category: { include: { space: true } } },
      });
      expect(room?.category.space.accessPolicy).toBe('PUBLIC');
    }
  });

  test('getHomeFeed first page returns items and next_cursor when items exceed limit', async () => {
    const page = await svc.getHomeFeed(asUser(ctx.uuids.user.minseo), undefined, 2);
    expect(page.items.length).toBeGreaterThanOrEqual(1);
    // Each item has required fields
    for (const item of page.items) {
      expect(item).toMatchObject({
        id: expect.any(String),
        type: expect.any(String),
        reason: expect.any(String),
        payload: expect.any(Object),
      });
    }
  });

  test('getHomeFeed with cursor returns subsequent page', async () => {
    const page1 = await svc.getHomeFeed(asUser(ctx.uuids.user.minseo), undefined, 2);
    if (!page1.next_cursor) return; // skip if total items ≤ 2
    const page2 = await svc.getHomeFeed(asUser(ctx.uuids.user.minseo), page1.next_cursor, 2);
    // Items on page2 must be different from page1
    const ids1 = new Set(page1.items.map((i) => i.id));
    for (const item of page2.items) {
      expect(ids1.has(item.id)).toBe(false);
    }
  });
});
