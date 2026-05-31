import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';
import { DmLifecycleCron } from '../src/modules/dm/dm-lifecycle.cron';

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

  test('a reported DM message can be globally hidden and drops from the thread', async () => {
    const server = ctx.app.getHttpServer();
    const open = await request(server)
      .post('/v1/dm/channels')
      .set(HEAD(ctx.uuids.user.joon))
      .send({ scope: 'RECRUITMENT', ref_id: recruitPostId });
    const channelId = open.body.id;

    const msg = await request(server)
      .post(`/v1/dm/channels/${channelId}/messages`)
      .set(HEAD(ctx.uuids.user.haneul))
      .send({ body: '신고 대상 메시지' });
    expect(msg.status).toBe(201);
    const messageId = msg.body.id;

    // A party reports the message (DM_MESSAGE reports are global-only).
    const report = await request(server)
      .post('/v1/reports')
      .set(HEAD(ctx.uuids.user.joon))
      .send({ target_type: 'DM_MESSAGE', target_id: messageId, reason: 'harassment' });
    expect(report.status).toBe(201);

    // A global moderator hides it.
    const resolve = await request(server)
      .post(`/v1/admin/reports/${report.body.id}/resolve`)
      .set(HEAD(ctx.uuids.user.coral))
      .send({ action: 'HIDE', note: 'confirmed' });
    expect(resolve.status).toBe(201);
    expect(resolve.body.resolution).toBe('HIDDEN');

    // The counterpart no longer sees the hidden message.
    const thread = await request(server)
      .get(`/v1/dm/channels/${channelId}/messages`)
      .set(HEAD(ctx.uuids.user.joon));
    expect(
      (thread.body.items as Array<{ id: string }>).some((m) => m.id === messageId),
    ).toBe(false);
  });

  test('an identical DM body sent repeatedly is auto-hidden', async () => {
    const server = ctx.app.getHttpServer();
    const open = await request(server)
      .post('/v1/dm/channels')
      .set(HEAD(ctx.uuids.user.joon))
      .send({ scope: 'RECRUITMENT', ref_id: recruitPostId });
    const channelId = open.body.id;
    const body = '동일한 스팸 메시지 본문';
    const send = () =>
      request(server)
        .post(`/v1/dm/channels/${channelId}/messages`)
        .set(HEAD(ctx.uuids.user.joon))
        .send({ body });

    const first = await send();
    expect(first.body.status).toBe('VISIBLE');
    const second = await send();
    expect(second.body.status).toBe('VISIBLE');
    // 3rd identical (threshold 2 prior matches) → auto-hidden.
    const third = await send();
    expect(third.body.status).toBe('HIDDEN');
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

  test('lifecycle cron closes channels past the 30-day grace', async () => {
    const server = ctx.app.getHttpServer();
    const cron = ctx.app.get(DmLifecycleCron);
    const open = await request(server)
      .post('/v1/dm/channels')
      .set(HEAD(ctx.uuids.user.joon))
      .send({ scope: 'RECRUITMENT', ref_id: recruitPostId });
    const channelId = open.body.id;
    // Stamp the workflow as ended 31 days ago → past the grace window.
    await ctx.prisma.dmChannel.update({
      where: { id: channelId },
      data: {
        status: 'OPEN',
        closedReason: null,
        workflowEndedAt: new Date(Date.now() - 31 * 86_400_000),
      },
    });
    const result = await cron.run(new Date());
    expect(result.closed).toBeGreaterThanOrEqual(1);
    const after = await ctx.prisma.dmChannel.findUnique({
      where: { id: channelId },
    });
    expect(after?.status).toBe('CLOSED');
    expect(after?.closedReason).toBe('WORKFLOW_ENDED_GRACE');
  });
});
