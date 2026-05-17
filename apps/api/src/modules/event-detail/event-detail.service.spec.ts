import { NotFoundException } from '@nestjs/common';
import { asUser, bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { EventDetailService } from './event-detail.service';

describe('EventDetailService', () => {
  let ctx: TestContext;
  let svc: EventDetailService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    svc = ctx.app.get(EventDetailService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  // -- happy paths -------------------------------------------------------

  test('e001 bundle has related_posts, related_rooms, sane counts, expected default room', async () => {
    const b = await svc.getBundle(
      ctx.uuids.event.e001,
      asUser(ctx.uuids.user.minseo),
    );
    expect(b.event_card.id).toBe(ctx.uuids.event.e001);
    expect(b.event_card.external_event_id).toBe('evt-001');
    expect(b.related_posts.items.length).toBeGreaterThanOrEqual(1);
    expect(b.related_posts.items[0].attachments.length).toBeGreaterThanOrEqual(1);
    expect(b.related_rooms.length).toBeGreaterThanOrEqual(1);
    expect(b.counts.post_count).toBeGreaterThanOrEqual(1);
    expect(b.counts.room_count).toBe(b.related_rooms.length);
    expect(b.default_compose_room_slug).toBe('dating-event-reviews');
    expect(b.verified_reviews).toEqual([]);
  });

  test('e002 bundle has the seeded haneul preview post', async () => {
    const b = await svc.getBundle(
      ctx.uuids.event.e002,
      asUser(ctx.uuids.user.minseo),
    );
    expect(b.related_posts.items.length).toBe(1);
    const post = b.related_posts.items[0];
    expect(post.body).toContain('환승연애 토크 라운드');
    expect(b.related_rooms.some((r) => r.slug === 'swap-style-talk-game')).toBe(true);
  });

  test('e003 (empty) returns empty related_posts but a usable default room via topic_hub_event_links', async () => {
    const b = await svc.getBundle(
      ctx.uuids.event.e003,
      asUser(ctx.uuids.user.minseo),
    );
    expect(b.related_posts.items).toHaveLength(0);
    expect(b.counts.post_count).toBe(0);
    expect(b.related_rooms).toHaveLength(0);
    // Falls through topic_hub_event_links → love-content OFFICIAL room.
    expect(b.default_compose_room_slug).toBe('dating-event-reviews');
  });

  test('unknown event card → NotFoundException', async () => {
    await expect(
      svc.getBundle(
        '00000000-0000-0000-0000-000000000000',
        asUser(ctx.uuids.user.minseo),
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  // -- pagination --------------------------------------------------------

  test('postsLimit caps the page, next_cursor pages forward', async () => {
    // Inject 4 extra posts in dating-event-reviews each attaching evt-001
    // so the page count is meaningful.
    for (let i = 0; i < 4; i += 1) {
      await ctx.prisma.post.create({
        data: {
          roomId: ctx.uuids.room.datingReviews,
          authorId: ctx.uuids.user.minseo,
          body: `evt-001 paging post ${i}`,
          attachments: {
            create: [
              {
                attachmentType: 'EVENT_CARD',
                targetId: ctx.uuids.event.e001,
                sortOrder: 1,
              },
            ],
          },
        },
      });
    }

    const page1 = await svc.getBundle(
      ctx.uuids.event.e001,
      asUser(ctx.uuids.user.minseo),
      { postsLimit: 2 },
    );
    expect(page1.related_posts.items).toHaveLength(2);
    expect(page1.related_posts.next_cursor).not.toBeNull();

    const page2 = await svc.getBundle(
      ctx.uuids.event.e001,
      asUser(ctx.uuids.user.minseo),
      { postsLimit: 2, postsCursor: page1.related_posts.next_cursor! },
    );
    expect(page2.related_posts.items.length).toBeGreaterThan(0);
    // No overlap between page 1 and page 2.
    const ids1 = new Set(page1.related_posts.items.map((p) => p.id));
    for (const p of page2.related_posts.items) {
      expect(ids1.has(p.id)).toBe(false);
    }
  });

  // -- soft delete -------------------------------------------------------

  test('soft-deleted posts are excluded from related_posts', async () => {
    const created = await ctx.prisma.post.create({
      data: {
        roomId: ctx.uuids.room.datingReviews,
        authorId: ctx.uuids.user.minseo,
        body: 'soon-to-be-deleted attaching evt-001',
        attachments: {
          create: [
            {
              attachmentType: 'EVENT_CARD',
              targetId: ctx.uuids.event.e001,
              sortOrder: 1,
            },
          ],
        },
      },
    });
    const before = await svc.getBundle(
      ctx.uuids.event.e001,
      asUser(ctx.uuids.user.minseo),
    );
    expect(before.related_posts.items.some((p) => p.id === created.id)).toBe(true);

    await ctx.prisma.post.update({
      where: { id: created.id },
      data: { status: 'DELETED' },
    });

    const after = await svc.getBundle(
      ctx.uuids.event.e001,
      asUser(ctx.uuids.user.minseo),
    );
    expect(after.related_posts.items.some((p) => p.id === created.id)).toBe(false);
  });

  // -- access-policy filtering ------------------------------------------

  test('planner-space posts attaching the same event are hidden from non-planners', async () => {
    // studio_lead drops a recruitment post in planner-recruitment that
    // also attaches evt-001.
    const plannerPost = await ctx.prisma.post.create({
      data: {
        roomId: ctx.uuids.room.plannerRecruitment,
        authorId: ctx.uuids.user.studio_lead,
        postType: 'RECRUITMENT',
        body: 'planner-only post mentioning evt-001 for staff brief',
        recruitmentFields: {
          role: '진행 어시',
          schedule: 'evt-001 day',
          location: '홍대 스튜디오',
          compensation: '8만원',
          capacity: 1,
          application_method: 'DM',
          status: 'OPEN',
        },
        attachments: {
          create: [
            {
              attachmentType: 'EVENT_CARD',
              targetId: ctx.uuids.event.e001,
              sortOrder: 1,
            },
          ],
        },
      },
    });

    const asMember = await svc.getBundle(
      ctx.uuids.event.e001,
      asUser(ctx.uuids.user.minseo),
    );
    expect(asMember.related_posts.items.some((p) => p.id === plannerPost.id)).toBe(false);
    expect(asMember.related_rooms.some((r) => r.slug === 'planner-recruitment')).toBe(false);

    const asPlanner = await svc.getBundle(
      ctx.uuids.event.e001,
      asUser(ctx.uuids.user.studio_lead, ['VERIFIED_PLANNER']),
    );
    expect(asPlanner.related_posts.items.some((p) => p.id === plannerPost.id)).toBe(true);
    expect(asPlanner.related_rooms.some((r) => r.slug === 'planner-recruitment')).toBe(true);
  });
});
