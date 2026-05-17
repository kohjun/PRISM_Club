import { BadRequestException, ConflictException, ForbiddenException } from '@nestjs/common';
import { asUser, bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { ReportService } from './report.service';

describe('ReportService', () => {
  let ctx: TestContext;
  let svc: ReportService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    svc = ctx.app.get(ReportService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('createReport saves an OPEN report', async () => {
    const r = await svc.createReport(
      {
        target_type: 'POST',
        target_id: ctx.uuids.post.minseoReview,
        reason: '스팸',
      },
      asUser(ctx.uuids.user.joon),
    );
    expect(r.status).toBe('OPEN');
    expect(r.target_type).toBe('POST');
  });

  test('duplicate OPEN report from same reporter is rejected (409)', async () => {
    await expect(
      svc.createReport(
        {
          target_type: 'POST',
          target_id: ctx.uuids.post.minseoReview,
          reason: '스팸',
        },
        asUser(ctx.uuids.user.joon),
      ),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  test('non-moderator listQueue is forbidden', async () => {
    await expect(svc.listQueue(asUser(ctx.uuids.user.joon))).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  test('MODERATOR sees the open queue including seeded report', async () => {
    const queue = await svc.listQueue(
      asUser(ctx.uuids.user.coral, ['MODERATOR']),
    );
    expect(queue.items.length).toBeGreaterThanOrEqual(1);
    expect(queue.items.every((r) => r.status === 'OPEN')).toBe(true);
  });

  test('resolve HIDE flips the target post to HIDDEN and creates audit record', async () => {
    const seededReportId = ctx.uuids.report.haneulOnRecruitTalkRound;
    const detail = await svc.resolve(
      seededReportId,
      { action: 'HIDE', note: '확인 후 숨김 처리' },
      asUser(ctx.uuids.user.coral, ['MODERATOR']),
    );
    expect(detail.status).toBe('RESOLVED');
    expect(detail.resolution).toBe('HIDDEN');
    expect(detail.actions.length).toBeGreaterThanOrEqual(1);

    // Verify target post was flipped
    const post = await ctx.prisma.post.findUnique({
      where: { id: ctx.uuids.post.joonQuestion },
    });
    expect(post?.status).toBe('HIDDEN');
  });

  test('resolve RESTORE on an already-resolved report is rejected', async () => {
    const seededReportId = ctx.uuids.report.haneulOnRecruitTalkRound;
    await expect(
      svc.resolve(
        seededReportId,
        { action: 'RESTORE' },
        asUser(ctx.uuids.user.coral, ['MODERATOR']),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  test('reporting yourself (USER target) is rejected', async () => {
    await expect(
      svc.createReport(
        {
          target_type: 'USER',
          target_id: ctx.uuids.user.minseo,
          reason: '테스트',
        },
        asUser(ctx.uuids.user.minseo),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
