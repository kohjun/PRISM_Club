import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('P7.3 — event recap suggest (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  // ----------------------------------------------------------------
  // Eligibility — who can call this endpoint
  // ----------------------------------------------------------------

  test('VERIFIED_PLANNER (studio_lead) gets a 200 with body, attachments, room slugs', async () => {
    const res = await request(ctx.app.getHttpServer())
      .post(`/v1/event-cards/${ctx.uuids.event.e001}/recap/suggest`)
      .set(HEAD(ctx.uuids.user.studio_lead));
    expect(res.status).toBe(200);
    expect(res.body.event.id).toBe(ctx.uuids.event.e001);
    expect(res.body.event.title).toContain('PRISM 소개팅');
    expect(typeof res.body.suggested_body).toBe('string');
    expect(res.body.suggested_body.length).toBeGreaterThan(0);
    expect(res.body.suggested_body).toContain('## PRISM 소개팅 미션 나이트 후기');
    expect(res.body.suggested_attachments).toEqual([
      { attachment_type: 'EVENT_CARD', target_id: ctx.uuids.event.e001 },
    ]);
    expect(Array.isArray(res.body.suggested_room_slugs)).toBe(true);
    // The loveContent category has dating-event-reviews,
    // love-show-references, and swap-style-talk-game; planner sees all
    // active rooms regardless of ownership.
    expect(res.body.suggested_room_slugs).toEqual(
      expect.arrayContaining([
        'dating-event-reviews',
        'swap-style-talk-game',
        'love-show-references',
      ]),
    );
  });

  test('room owner (haneul owns swap-style-talk-game) gets 200 with owned slug first', async () => {
    const res = await request(ctx.app.getHttpServer())
      .post(`/v1/event-cards/${ctx.uuids.event.e001}/recap/suggest`)
      .set(HEAD(ctx.uuids.user.haneul));
    expect(res.status).toBe(200);
    expect(res.body.suggested_room_slugs[0]).toBe('swap-style-talk-game');
    expect(res.body.suggested_room_slugs).toContain('dating-event-reviews');
  });

  test('regular member (minseo) gets 403 — not organizer, not planner', async () => {
    const res = await request(ctx.app.getHttpServer())
      .post(`/v1/event-cards/${ctx.uuids.event.e001}/recap/suggest`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(res.status).toBe(403);
    expect(res.body.message).toContain('운영자 또는 검증된 기획자');
  });

  // ----------------------------------------------------------------
  // Status gate — event must be COMPLETED
  // ----------------------------------------------------------------

  test('UPCOMING event (e002) returns 400 even for planner', async () => {
    const res = await request(ctx.app.getHttpServer())
      .post(`/v1/event-cards/${ctx.uuids.event.e002}/recap/suggest`)
      .set(HEAD(ctx.uuids.user.studio_lead));
    expect(res.status).toBe(400);
    expect(res.body.message).toContain('완료된 이벤트');
  });

  // ----------------------------------------------------------------
  // Not-found
  // ----------------------------------------------------------------

  test('unknown event card → 404', async () => {
    const res = await request(ctx.app.getHttpServer())
      .post('/v1/event-cards/00000000-0000-0000-0000-000000000000/recap/suggest')
      .set(HEAD(ctx.uuids.user.studio_lead));
    expect(res.status).toBe(404);
  });

  // ----------------------------------------------------------------
  // Body composition — when reviews + RSVP exist, the response uses them
  // ----------------------------------------------------------------

  test('after seeding a review + ATTENDED RSVP, the body includes that signal', async () => {
    const server = ctx.app.getHttpServer();
    const e001 = ctx.uuids.event.e001;

    // Mark minseo as ATTENDED so we can post a review.
    await ctx.prisma.eventRsvp.upsert({
      where: {
        eventCardId_userId: { eventCardId: e001, userId: ctx.uuids.user.minseo },
      },
      create: {
        eventCardId: e001,
        userId: ctx.uuids.user.minseo,
        status: 'ATTENDED',
      },
      update: { status: 'ATTENDED' },
    });
    // Drop any prior review so this test is idempotent across runs.
    await ctx.prisma.eventReview.deleteMany({
      where: { eventCardId: e001, userId: ctx.uuids.user.minseo },
    });
    await ctx.prisma.eventReview.create({
      data: {
        eventCardId: e001,
        userId: ctx.uuids.user.minseo,
        rating: 5,
        body: '진행 매끄럽고 게임 매칭 잘 됐어요. 음식도 괜찮음.',
        status: 'VISIBLE',
      },
    });

    const res = await request(server)
      .post(`/v1/event-cards/${e001}/recap/suggest`)
      .set(HEAD(ctx.uuids.user.studio_lead));
    expect(res.status).toBe(200);
    expect(res.body.suggested_body).toContain('가장 많이 공감받은 후기');
    expect(res.body.suggested_body).toContain('진행 매끄럽고');
    expect(res.body.suggested_body).toContain('이번 이벤트 평균 평점');
    expect(res.body.suggested_body).toContain('참석 ');
  });

  test('empty-event fallback copy appears when there are no signals', async () => {
    const server = ctx.app.getHttpServer();
    const e001 = ctx.uuids.event.e001;

    // Clear out any signals seeded by previous tests in this file.
    await ctx.prisma.eventReview.deleteMany({ where: { eventCardId: e001 } });
    await ctx.prisma.eventLivePost.deleteMany({ where: { eventCardId: e001 } });
    await ctx.prisma.eventRsvp.deleteMany({ where: { eventCardId: e001 } });

    const res = await request(server)
      .post(`/v1/event-cards/${e001}/recap/suggest`)
      .set(HEAD(ctx.uuids.user.studio_lead));
    expect(res.status).toBe(200);
    expect(res.body.suggested_body).toContain('아직 이번 이벤트에 후기나 라이브 글이 없네요');
  });
});
