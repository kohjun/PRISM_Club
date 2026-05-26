import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';
import { TopicHubSimilarityService } from '../src/modules/knowledge/topic-hub-similarity.service';

describe('P7.1 — topic hub similarity (e2e)', () => {
  let ctx: TestContext;
  // Seed only ships one TopicHub (love-content). To exercise hub→hub
  // similarity we plant a second hub here that shares contributor rows
  // and at least one room with love-content, then run recompute and
  // assert the GET endpoint surfaces the resulting edge.

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('with no second hub, recompute writes 0 rows and GET returns []', async () => {
    // Sanity check before we add a second hub: love-content's similar
    // list is empty because there's no other hub to compare against.
    const svc = ctx.app.get(TopicHubSimilarityService);
    const before = await svc.recomputeAll();
    expect(before.rows_written).toBe(0);

    const res = await request(ctx.app.getHttpServer())
      .get('/v1/topic-hubs/love-content/similar')
      .set('X-User-Id', ctx.uuids.user.minseo);
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  test('after planting a sibling hub that shares contributors + rooms, GET returns it', async () => {
    // 1. Stand up a sibling category + topic hub inside the same PUBLIC
    //    space as love-content (so accessPolicy doesn't block anyone).
    const cat = await ctx.prisma.category.create({
      data: {
        spaceId: ctx.uuids.space.participant,
        slug: 'recruit-content',
        name: '모집 콘텐츠',
      },
    });
    const sibling = await ctx.prisma.topicHub.create({
      data: {
        categoryId: cat.id,
        title: '모집 콘텐츠 허브',
        summary: '리쿠르팅 관련 지식 묶음.',
      },
    });

    // 2. Plant a knowledge block in the sibling so that we can attach a
    //    revision authored by coral — coral already has APPROVED
    //    contributions on love-content via the seed, so this creates
    //    shared contributor overlap.
    const block = await ctx.prisma.knowledgeBlock.create({
      data: {
        topicHubId: sibling.id,
        blockType: 'OVERVIEW',
        title: '모집 글 작성 가이드',
        body: '기본 모집 글 템플릿',
        sortOrder: 0,
      },
    });
    await ctx.prisma.knowledgeBlockRevision.create({
      data: {
        blockId: block.id,
        version: 1,
        blockType: 'OVERVIEW',
        title: '모집 글 작성 가이드',
        body: '기본 모집 글 템플릿',
        changedById: ctx.uuids.user.coral,
        source: 'SEED',
      },
    });

    // 3. Plant a room in the sibling category that shares ownership
    //    with one of love-content's rooms (using the same owner =
    //    haneul). The owner-overlap doesn't drive the similarity
    //    directly, but a non-empty room set on both sides keeps the
    //    union math meaningful.
    await ctx.prisma.room.create({
      data: {
        categoryId: cat.id,
        ownerId: ctx.uuids.user.haneul,
        slug: 'recruit-room-talks',
        name: '모집 방',
        description: 'P7.1 e2e fixture',
        origin: 'USER',
        roomType: 'DISCUSSION',
        tags: [],
      },
    });

    // 4. Recompute + read.
    const svc = ctx.app.get(TopicHubSimilarityService);
    const result = await svc.recomputeAll();
    expect(result.hubs_scanned).toBe(2);
    expect(result.rows_written).toBeGreaterThan(0);

    const res = await request(ctx.app.getHttpServer())
      .get('/v1/topic-hubs/love-content/similar')
      .set('X-User-Id', ctx.uuids.user.minseo);
    expect(res.status).toBe(200);
    expect(res.body.length).toBeGreaterThanOrEqual(1);

    const top = res.body[0];
    expect(top.topic_hub.slug).toBe('recruit-content');
    expect(top.topic_hub.title).toBe('모집 콘텐츠 허브');
    expect(top.score).toBeGreaterThan(0);
    expect(top.reason).toMatchObject({
      shared_contributor_count: expect.any(Number),
      shared_room_count: expect.any(Number),
    });
    expect(top.reason.shared_contributor_count).toBeGreaterThanOrEqual(1);
  });

  test('unknown slug returns 404', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get('/v1/topic-hubs/no-such-hub/similar')
      .set('X-User-Id', ctx.uuids.user.minseo);
    expect(res.status).toBe(404);
  });

  test('GET is Public — anonymous viewers see PUBLIC→PUBLIC edges', async () => {
    // No X-User-Id header → controller treats viewer as anonymous.
    // Both source and sibling hubs are PUBLIC so the edge should still
    // be visible.
    const res = await request(ctx.app.getHttpServer()).get(
      '/v1/topic-hubs/love-content/similar',
    );
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('admin recompute endpoint rejects non-admin', async () => {
    const res = await request(ctx.app.getHttpServer())
      .post('/v1/admin/recommendations/topic-hub-similarity/recompute')
      .set('X-User-Id', ctx.uuids.user.coral); // CURATOR + MODERATOR, not ADMIN
    expect(res.status).toBe(403);
  });
});
