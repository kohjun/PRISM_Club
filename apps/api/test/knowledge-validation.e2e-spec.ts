import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('P7.2 — knowledge validation + chain (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('GET /validation returns score, label, and signal counts', async () => {
    // Pick any seeded block.
    const block = await ctx.prisma.knowledgeBlock.findFirstOrThrow({
      where: { hub: { category: { slug: 'love-content' } } },
      orderBy: { sortOrder: 'asc' },
    });

    const res = await request(ctx.app.getHttpServer())
      .get(`/v1/knowledge-blocks/${block.id}/validation`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(res.status).toBe(200);
    expect(res.body.block_id).toBe(block.id);
    expect(typeof res.body.score).toBe('number');
    expect(['검증 부족', '검증 진행 중', '충분히 검증됨']).toContain(res.body.label);
    expect(res.body.signals).toMatchObject({
      revisions: expect.any(Number),
      approvals: expect.any(Number),
      avg_reputation: expect.any(Number),
      age_days: expect.any(Number),
    });
    expect(res.body.signals.revisions).toBeGreaterThanOrEqual(0);
    expect(res.body.signals.age_days).toBeLessThanOrEqual(30);
  });

  test('approving a contribution increases the score', async () => {
    const block = await ctx.prisma.knowledgeBlock.findFirstOrThrow({
      where: { hub: { category: { slug: 'love-content' } } },
      orderBy: { sortOrder: 'asc' },
    });
    const baseline = await request(ctx.app.getHttpServer())
      .get(`/v1/knowledge-blocks/${block.id}/validation`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(baseline.status).toBe(200);
    const baselineScore = baseline.body.score as number;

    // Plant an APPROVED contribution + a CONTRIBUTION revision row so
    // the signals both move. Done directly on prisma — going through
    // the contribution-resolve flow would also work but adds noise.
    const before = await ctx.prisma.knowledgeContribution.count({
      where: { targetBlockId: block.id, status: 'APPROVED' },
    });
    await ctx.prisma.knowledgeContribution.create({
      data: {
        topicHubId: block.topicHubId,
        contributorId: ctx.uuids.user.minseo,
        targetBlockId: block.id,
        proposedBlockType: block.blockType,
        proposedTitle: block.title,
        proposedBody: 'P7.2 e2e fixture',
        status: 'APPROVED',
        resolvedBy: ctx.uuids.user.coral,
      },
    });
    const latestRev = await ctx.prisma.knowledgeBlockRevision.findFirst({
      where: { blockId: block.id },
      orderBy: { version: 'desc' },
      select: { version: true },
    });
    await ctx.prisma.knowledgeBlockRevision.create({
      data: {
        blockId: block.id,
        version: (latestRev?.version ?? 0) + 1,
        blockType: block.blockType,
        title: block.title,
        body: 'P7.2 e2e revision',
        source: 'CONTRIBUTION',
        changedById: ctx.uuids.user.minseo,
      },
    });

    const after = await request(ctx.app.getHttpServer())
      .get(`/v1/knowledge-blocks/${block.id}/validation`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(after.status).toBe(200);
    expect(after.body.signals.approvals).toBe(before + 1);
    expect(after.body.score).toBeGreaterThan(baselineScore);
  });

  test('GET /chain returns timeline entries with role + nickname', async () => {
    const block = await ctx.prisma.knowledgeBlock.findFirstOrThrow({
      where: { hub: { category: { slug: 'love-content' } } },
      orderBy: { sortOrder: 'asc' },
    });
    const res = await request(ctx.app.getHttpServer())
      .get(`/v1/knowledge-blocks/${block.id}/chain`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(res.status).toBe(200);
    expect(res.body.block_id).toBe(block.id);
    expect(Array.isArray(res.body.items)).toBe(true);
    if (res.body.items.length > 0) {
      const entry = res.body.items[0];
      expect(['SEED', 'CONTRIBUTION', 'ADMIN']).toContain(entry.role_in_chain);
      expect(typeof entry.acted_at).toBe('string');
      expect(typeof entry.revision_version).toBe('number');
    }
  });

  test('unknown block id → 404 on both endpoints', async () => {
    const ghost = '00000000-0000-0000-0000-000000000000';
    const v = await request(ctx.app.getHttpServer())
      .get(`/v1/knowledge-blocks/${ghost}/validation`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(v.status).toBe(404);
    const c = await request(ctx.app.getHttpServer())
      .get(`/v1/knowledge-blocks/${ghost}/chain`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(c.status).toBe(404);
  });

  test('PLANNER_ONLY block returns 404 to a non-planner viewer', async () => {
    // Create a planner-space category + hub + block on the fly. We
    // can't just rely on the seed because love-content is PUBLIC.
    const space = await ctx.prisma.space.findFirstOrThrow({
      where: { accessPolicy: 'PLANNER_ONLY' },
    });
    const cat = await ctx.prisma.category.create({
      data: {
        spaceId: space.id,
        slug: 'planner-only-validation-fixture',
        name: 'P7.2 fixture',
      },
    });
    const hub = await ctx.prisma.topicHub.create({
      data: {
        categoryId: cat.id,
        title: 'P7.2 PLANNER fixture hub',
        summary: 'fixture',
      },
    });
    const block = await ctx.prisma.knowledgeBlock.create({
      data: {
        topicHubId: hub.id,
        blockType: 'OVERVIEW',
        title: 'fixture',
        body: 'fixture body',
        sortOrder: 0,
      },
    });

    // Regular user (minseo, no planner role) → expect 404, not 403,
    // so the existence of the row stays private.
    const blocked = await request(ctx.app.getHttpServer())
      .get(`/v1/knowledge-blocks/${block.id}/validation`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(blocked.status).toBe(404);

    // Planner sees the row normally.
    const ok = await request(ctx.app.getHttpServer())
      .get(`/v1/knowledge-blocks/${block.id}/validation`)
      .set(HEAD(ctx.uuids.user.studio_lead));
    expect(ok.status).toBe(200);
  });
});
