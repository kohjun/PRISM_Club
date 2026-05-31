import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('P6.11 — Topic Hub Memory / me/memories (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  // Fixed anniversary base date for deterministic windows.
  const BASE = '2026-03-15';

  beforeAll(async () => {
    ctx = await bootstrapTestApp();

    // minseo already follows datingReviews (created "now" by seed).
    // Pin its createdAt to exactly one year before BASE so it becomes
    // a "1년 전 오늘" memory.
    await ctx.prisma.roomFollow.update({
      where: { id: ctx.uuids.follow.minseoDatingReviews },
      data: { createdAt: new Date('2025-03-15T08:00:00.000Z') },
    });

    // Plant an EventRsvp two years before BASE → "2년 전 오늘".
    await ctx.prisma.eventRsvp.upsert({
      where: {
        eventCardId_userId: {
          eventCardId: ctx.uuids.event.e001,
          userId: ctx.uuids.user.minseo,
        },
      },
      create: {
        eventCardId: ctx.uuids.event.e001,
        userId: ctx.uuids.user.minseo,
        status: 'INTERESTED',
        createdAt: new Date('2024-03-15T09:00:00.000Z'),
      },
      update: { createdAt: new Date('2024-03-15T09:00:00.000Z') },
    });
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('returns the 1yr + 2yr anniversary items for BASE date, newest first', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get(`/v1/me/memories?date=${BASE}`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(res.status).toBe(200);
    expect(res.body.date).toBe(BASE);

    const items = res.body.items as Array<Record<string, unknown>>;
    const follow = items.find((i) => i.kind === 'ROOM_FOLLOW');
    const rsvp = items.find((i) => i.kind === 'EVENT_RSVP');

    expect(follow).toBeDefined();
    expect(follow!.years_ago).toBe(1);
    expect(follow!.deep_link).toBe('/rooms/dating-event-reviews');
    expect(String(follow!.subtitle)).toContain('1년 전 오늘');

    expect(rsvp).toBeDefined();
    expect(rsvp!.years_ago).toBe(2);
    expect(String(rsvp!.deep_link)).toContain('/events/');

    // Newest anniversary moment first → the 1yr-ago follow (2025) sorts
    // ahead of the 2yr-ago rsvp (2024).
    const followIdx = items.indexOf(follow!);
    const rsvpIdx = items.indexOf(rsvp!);
    expect(followIdx).toBeLessThan(rsvpIdx);
  });

  test('a row just outside the anniversary window does not appear', async () => {
    // Move the follow off the anniversary by two days; it should drop.
    await ctx.prisma.roomFollow.update({
      where: { id: ctx.uuids.follow.minseoDatingReviews },
      data: { createdAt: new Date('2025-03-17T08:00:00.000Z') },
    });
    const res = await request(ctx.app.getHttpServer())
      .get(`/v1/me/memories?date=${BASE}`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(res.status).toBe(200);
    const kinds = (res.body.items as Array<{ kind: string }>).map(
      (i) => i.kind,
    );
    expect(kinds).not.toContain('ROOM_FOLLOW');
    // restore for any later run isolation
    await ctx.prisma.roomFollow.update({
      where: { id: ctx.uuids.follow.minseoDatingReviews },
      data: { createdAt: new Date('2025-03-15T08:00:00.000Z') },
    });
  });

  test('a date with no anniversary activity returns an empty list', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get('/v1/me/memories?date=2026-07-04')
      .set(HEAD(ctx.uuids.user.minseo));
    expect(res.status).toBe(200);
    expect(res.body.date).toBe('2026-07-04');
    expect(res.body.items).toEqual([]);
  });

  test('defaults to today when date is omitted (200 + array)', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get('/v1/me/memories')
      .set(HEAD(ctx.uuids.user.minseo));
    expect(res.status).toBe(200);
    expect(typeof res.body.date).toBe('string');
    expect(Array.isArray(res.body.items)).toBe(true);
  });
});
