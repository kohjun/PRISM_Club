import { ForbiddenException } from '@nestjs/common';
import {
  asUser,
  bootstrapTestApp,
  teardownTestApp,
  TestContext,
} from '../../../test/test-app';
import { AnalyticsService } from './analytics.service';

describe('AnalyticsService', () => {
  let ctx: TestContext;
  let svc: AnalyticsService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    svc = ctx.app.get(AnalyticsService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  beforeEach(async () => {
    // Clear analytics rows between tests so we can count cleanly
    await ctx.prisma.analyticsEvent.deleteMany({});
  });

  test('record() writes a row asynchronously and never throws', async () => {
    expect(() =>
      svc.record({
        actorId: ctx.uuids.user.minseo,
        eventType: 'AUTH_LOGIN',
        payload: { roles_count: 1 },
      }),
    ).not.toThrow();

    // Wait briefly for the fire-and-forget create to land
    await new Promise((r) => setTimeout(r, 50));

    const rows = await ctx.prisma.analyticsEvent.findMany({
      where: { eventType: 'AUTH_LOGIN' },
    });
    expect(rows.length).toBe(1);
    expect(rows[0].actorId).toBe(ctx.uuids.user.minseo);
    expect((rows[0].payload as Record<string, unknown>).roles_count).toBe(1);
  });

  test('record() never throws even if payload is exotic', async () => {
    expect(() =>
      svc.record({
        actorId: null,
        eventType: 'POST_CREATED',
        payload: { weird: { nested: 'object' }, count: 5 },
      }),
    ).not.toThrow();
    await new Promise((r) => setTimeout(r, 50));
    const rows = await ctx.prisma.analyticsEvent.findMany({
      where: { eventType: 'POST_CREATED' },
    });
    expect(rows.length).toBe(1);
    // nested objects are dropped by scrubber; primitives kept
    const p = rows[0].payload as Record<string, unknown>;
    expect(p.count).toBe(5);
    expect(p.weird).toBeUndefined();
  });

  test('scrubPayload drops forbidden keys (body, message, email, etc.)', async () => {
    svc.record({
      actorId: ctx.uuids.user.minseo,
      eventType: 'REPLY_CREATED',
      payload: {
        reply_id: 'r-1',
        body: 'should-not-appear',
        message: 'no',
        email: 'a@b.c',
        password: 'secret',
        access_token: 'tok',
      },
    });
    await new Promise((r) => setTimeout(r, 50));
    const row = await ctx.prisma.analyticsEvent.findFirst({
      where: { eventType: 'REPLY_CREATED' },
    });
    const p = row!.payload as Record<string, unknown>;
    expect(p.reply_id).toBe('r-1');
    expect(p.body).toBeUndefined();
    expect(p.message).toBeUndefined();
    expect(p.email).toBeUndefined();
    expect(p.password).toBeUndefined();
    expect(p.access_token).toBeUndefined();
  });

  test('scrubPayload truncates long strings to 120 chars + ellipsis', async () => {
    const long = 'x'.repeat(500);
    svc.record({
      actorId: ctx.uuids.user.minseo,
      eventType: 'ROOM_FOLLOWED',
      payload: { note: long },
    });
    await new Promise((r) => setTimeout(r, 50));
    const row = await ctx.prisma.analyticsEvent.findFirst({
      where: { eventType: 'ROOM_FOLLOWED' },
    });
    const note = (row!.payload as Record<string, unknown>).note as string;
    expect(note.length).toBeLessThanOrEqual(121); // 120 + ellipsis char
    expect(note.endsWith('…')).toBe(true);
  });

  test('summarize requires an ops role', async () => {
    await expect(
      svc.summarize(asUser(ctx.uuids.user.minseo, ['MEMBER'])),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  test('summarize returns 30-day counts grouped by event_type for admin', async () => {
    // Seed a few events
    svc.record({
      actorId: ctx.uuids.user.minseo,
      eventType: 'AUTH_LOGIN',
      payload: {},
    });
    svc.record({
      actorId: ctx.uuids.user.minseo,
      eventType: 'AUTH_LOGIN',
      payload: {},
    });
    svc.record({
      actorId: ctx.uuids.user.minseo,
      eventType: 'POST_CREATED',
      payload: {},
    });
    await new Promise((r) => setTimeout(r, 80));

    const out = await svc.summarize(asUser(ctx.uuids.user.coral, ['CURATOR']));
    expect(out.window_days).toBe(30);
    expect(out.counts.length).toBeGreaterThanOrEqual(2);
    const loginCount =
      out.counts.find((c) => c.event_type === 'AUTH_LOGIN')?.count ?? 0;
    const postCount =
      out.counts.find((c) => c.event_type === 'POST_CREATED')?.count ?? 0;
    expect(loginCount).toBe(2);
    expect(postCount).toBe(1);
  });

  test('summarize allows MODERATOR and ADMIN roles too', async () => {
    await expect(
      svc.summarize(asUser('any-mod', ['MODERATOR'])),
    ).resolves.toBeDefined();
    await expect(
      svc.summarize(asUser('any-admin', ['ADMIN'])),
    ).resolves.toBeDefined();
  });
});
