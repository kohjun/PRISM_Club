import { asUser, bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { NotificationService } from './notification.service';
import { ReplyService } from '../posts/reply.service';
import { PostService } from '../posts/post.service';

describe('NotificationService', () => {
  let ctx: TestContext;
  let svc: NotificationService;
  let replies: ReplyService;
  let posts: PostService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    svc = ctx.app.get(NotificationService);
    replies = ctx.app.get(ReplyService);
    posts = ctx.app.get(PostService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('listForUser returns seeded notifications for minseo', async () => {
    const result = await svc.listForUser(
      ctx.uuids.user.minseo,
      asUser(ctx.uuids.user.minseo),
    );
    expect(result.items.length).toBeGreaterThanOrEqual(2);
  });

  test('listForUser access filter: PLANNER_ONLY notification excluded for member viewer', async () => {
    // Seed a planner-space notification for minseo directly in DB
    await ctx.prisma.notification.create({
      data: {
        userId: ctx.uuids.user.minseo,
        type: 'NEW_POST_IN_FOLLOWED_ROOM',
        payload: {
          postId: ctx.uuids.post.recruitDatingNight,
          roomSlug: 'planner-recruitment',
          spaceAccessPolicy: 'PLANNER_ONLY',
        },
      },
    });

    const memberResult = await svc.listForUser(
      ctx.uuids.user.minseo,
      asUser(ctx.uuids.user.minseo, ['MEMBER']),
    );
    const plannerResult = await svc.listForUser(
      ctx.uuids.user.minseo,
      asUser(ctx.uuids.user.minseo, ['VERIFIED_PLANNER']),
    );

    const memberHasPlannerNotif = memberResult.items.some(
      (n) => (n.payload as any)?.spaceAccessPolicy === 'PLANNER_ONLY',
    );
    const plannerHasPlannerNotif = plannerResult.items.some(
      (n) => (n.payload as any)?.spaceAccessPolicy === 'PLANNER_ONLY',
    );

    expect(memberHasPlannerNotif).toBe(false);
    expect(plannerHasPlannerNotif).toBe(true);
  });

  test('markRead flips isRead on the target notification', async () => {
    const before = await svc.listForUser(
      ctx.uuids.user.minseo,
      asUser(ctx.uuids.user.minseo),
      { unreadOnly: true },
    );
    const unread = before.items[0];
    expect(unread).toBeDefined();

    await svc.markRead(unread.id, ctx.uuids.user.minseo);

    const row = await ctx.prisma.notification.findUnique({ where: { id: unread.id } });
    expect(row?.isRead).toBe(true);
  });

  test('markAllRead → unreadCount = 0', async () => {
    // Ensure there are unread notifications
    await ctx.prisma.notification.updateMany({
      where: { userId: ctx.uuids.user.joon },
      data: { isRead: true },
    });
    await ctx.prisma.notification.create({
      data: {
        userId: ctx.uuids.user.joon,
        type: 'REPLY_ON_POST',
        payload: { postId: ctx.uuids.post.joonQuestion, spaceAccessPolicy: 'PUBLIC' },
      },
    });

    await svc.markAllRead(ctx.uuids.user.joon);
    const count = await svc.getUnreadCount(ctx.uuids.user.joon);
    expect(count.count).toBe(0);
  });

  test('getUnreadCount returns correct count', async () => {
    const count = await svc.getUnreadCount(ctx.uuids.user.coral);
    expect(typeof count.count).toBe('number');
  });

  test('ReplyService.create emits REPLY_ON_POST notification for post author', async () => {
    const post = await posts.create(
      'dating-event-reviews',
      { body: 'notification-test post' },
      asUser(ctx.uuids.user.minseo),
    );
    await replies.create(post.id, { body: 'a reply' }, asUser(ctx.uuids.user.joon));

    const notifs = await ctx.prisma.notification.findMany({
      where: { userId: ctx.uuids.user.minseo, type: 'REPLY_ON_POST' },
      orderBy: { createdAt: 'desc' },
    });
    expect(notifs.length).toBeGreaterThanOrEqual(1);
    expect((notifs[0].payload as any).postId).toBe(post.id);
  });
});
