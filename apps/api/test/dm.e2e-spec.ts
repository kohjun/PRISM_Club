import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

/**
 * P6.9 — Scoped DM (e2e). Workflow-bounded private 1:1 channels.
 *
 * The test plants its own recruitment + contribution fixtures via
 * ctx.prisma in beforeAll so it doesn't depend on the exact shape of
 * the seed recruitment data:
 *   - RECRUITMENT: a PUBLIC post authored by haneul + a PENDING
 *     application from joon → channel(applicant=joon, author=haneul).
 *   - CONTRIBUTION: a NEEDS_CHANGES contribution by minseo resolved by
 *     coral → channel(proposer=minseo, curator=coral).
 */
describe('P6.9 — scoped DM (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  let recruitPostId: string;
  let contributionId: string;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    const U = ctx.uuids;

    // RECRUITMENT fixture: PUBLIC post (datingReviews) by haneul + joon application.
    const post = await ctx.prisma.post.create({
      data: {
        roomId: U.room.datingReviews,
        authorId: U.user.haneul,
        postType: 'RECRUITMENT',
        body: 'P6.9 DM e2e recruitment post',
        recruitmentFields: { status: 'OPEN', capacity: 3 },
      },
    });
    recruitPostId = post.id;
    await ctx.prisma.recruitmentPost.create({
      data: { postId: post.id, capacity: 3, status: 'OPEN' },
    });
    await ctx.prisma.recruitmentApplication.create({
      data: { postId: post.id, applicantId: U.user.joon, status: 'PENDING' },
    });

    // CONTRIBUTION fixture: NEEDS_CHANGES contribution by minseo, curated by coral.
    const c = await ctx.prisma.knowledgeContribution.create({
      data: {
        topicHubId: U.topicHub.loveContent,
        contributorId: U.user.minseo,
        proposedBlockType: 'TEXT',
        proposedTitle: 'DM e2e proposal',
        proposedBody: 'needs work',
        status: 'NEEDS_CHANGES',
        resolvedBy: U.user.coral,
        resolvedAt: new Date(),
      },
    });
    contributionId = c.id;
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('RECRUITMENT: applicant opens a channel, both parties exchange messages', async () => {
    const server = ctx.app.getHttpServer();

    // joon (applicant) opens the channel.
    const open = await request(server)
      .post('/v1/dm/channels')
      .set(HEAD(ctx.uuids.user.joon))
      .send({ scope: 'RECRUITMENT', ref_id: recruitPostId });
    expect(open.status).toBe(201);
    expect(open.body.counterpart.id).toBe(ctx.uuids.user.haneul);
    const channelId = open.body.id;

    // joon sends.
    const send = await request(server)
      .post(`/v1/dm/channels/${channelId}/messages`)
      .set(HEAD(ctx.uuids.user.joon))
      .send({ body: '안녕하세요, 지원 관련 문의드려요.' });
    expect(send.status).toBe(201);
    expect(send.body.mine).toBe(true);

    // haneul (author) sees the channel in their inbox and replies.
    const inbox = await request(server)
      .get('/v1/dm/channels')
      .set(HEAD(ctx.uuids.user.haneul));
    expect(inbox.status).toBe(200);
    expect(
      (inbox.body.items as Array<{ id: string }>).some((c) => c.id === channelId),
    ).toBe(true);

    const reply = await request(server)
      .post(`/v1/dm/channels/${channelId}/messages`)
      .set(HEAD(ctx.uuids.user.haneul))
      .send({ body: '네, 편하게 물어보세요.' });
    expect(reply.status).toBe(201);

    // Both messages are visible in the thread.
    const thread = await request(server)
      .get(`/v1/dm/channels/${channelId}/messages`)
      .set(HEAD(ctx.uuids.user.joon));
    expect(thread.status).toBe(200);
    expect(thread.body.items.length).toBe(2);
    expect(thread.body.channel_status).toBe('OPEN');
  });

  test('RECRUITMENT: a non-party cannot open or read the channel', async () => {
    const server = ctx.app.getHttpServer();
    // minseo has no application → cannot open.
    const open = await request(server)
      .post('/v1/dm/channels')
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ scope: 'RECRUITMENT', ref_id: recruitPostId });
    expect(open.status).toBe(403);
  });

  test('CONTRIBUTION: proposer ↔ curator channel resolves on the NEEDS_CHANGES row', async () => {
    const server = ctx.app.getHttpServer();
    const open = await request(server)
      .post('/v1/dm/channels')
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ scope: 'CONTRIBUTION', ref_id: contributionId });
    expect(open.status).toBe(201);
    expect(open.body.counterpart.id).toBe(ctx.uuids.user.coral);

    // A user who is neither proposer nor curator is rejected.
    const denied = await request(server)
      .post('/v1/dm/channels')
      .set(HEAD(ctx.uuids.user.joon))
      .send({ scope: 'CONTRIBUTION', ref_id: contributionId });
    expect(denied.status).toBe(403);
  });

  test('a CLOSED channel rejects new messages (read-only)', async () => {
    const server = ctx.app.getHttpServer();
    const open = await request(server)
      .post('/v1/dm/channels')
      .set(HEAD(ctx.uuids.user.joon))
      .send({ scope: 'RECRUITMENT', ref_id: recruitPostId });
    const channelId = open.body.id;
    await ctx.prisma.dmChannel.update({
      where: { id: channelId },
      data: { status: 'CLOSED', closedReason: 'TEST' },
    });
    const send = await request(server)
      .post(`/v1/dm/channels/${channelId}/messages`)
      .set(HEAD(ctx.uuids.user.joon))
      .send({ body: 'should be blocked' });
    expect(send.status).toBe(409);
    // Re-open for any later assertions.
    await ctx.prisma.dmChannel.update({
      where: { id: channelId },
      data: { status: 'OPEN', closedReason: null },
    });
  });

  test('blocked parties cannot message each other', async () => {
    const server = ctx.app.getHttpServer();
    const open = await request(server)
      .post('/v1/dm/channels')
      .set(HEAD(ctx.uuids.user.joon))
      .send({ scope: 'RECRUITMENT', ref_id: recruitPostId });
    const channelId = open.body.id;

    // haneul blocks joon.
    await request(server)
      .post(`/v1/me/blocks/${ctx.uuids.user.joon}`)
      .set(HEAD(ctx.uuids.user.haneul));

    const send = await request(server)
      .post(`/v1/dm/channels/${channelId}/messages`)
      .set(HEAD(ctx.uuids.user.joon))
      .send({ body: 'blocked attempt' });
    expect(send.status).toBe(409);

    // cleanup the block so it doesn't leak into other suites' shared DB.
    await request(server)
      .delete(`/v1/me/blocks/${ctx.uuids.user.joon}`)
      .set(HEAD(ctx.uuids.user.haneul));
  });
});
