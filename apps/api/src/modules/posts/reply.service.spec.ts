import { BadRequestException, NotFoundException } from '@nestjs/common';
import { asUser, bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { ReplyService } from './reply.service';
import { PostService } from './post.service';

describe('ReplyService', () => {
  let ctx: TestContext;
  let replies: ReplyService;
  let posts: PostService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    replies = ctx.app.get(ReplyService);
    posts = ctx.app.get(PostService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('allows replies up to depth 2 and rejects depth 3', async () => {
    const post = await posts.create(
      'dating-event-reviews',
      { body: 'depth-test post' },
      asUser(ctx.uuids.user.minseo),
    );

    const r1 = await replies.create(post.id, { body: 'r1' }, asUser(ctx.uuids.user.joon));
    expect(r1.parent_reply_id).toBeNull();

    const r2 = await replies.create(
      post.id,
      { body: 'r2', parent_reply_id: r1.id },
      asUser(ctx.uuids.user.haneul),
    );
    expect(r2.parent_reply_id).toBe(r1.id);

    await expect(
      replies.create(post.id, { body: 'r3', parent_reply_id: r2.id }, asUser(ctx.uuids.user.joon)),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  test('rejects parent_reply_id from a different post', async () => {
    const postA = await posts.create(
      'dating-event-reviews',
      { body: 'post A' },
      asUser(ctx.uuids.user.minseo),
    );
    const postB = await posts.create(
      'dating-event-reviews',
      { body: 'post B' },
      asUser(ctx.uuids.user.minseo),
    );
    const r = await replies.create(postA.id, { body: 'rA' }, asUser(ctx.uuids.user.joon));

    await expect(
      replies.create(postB.id, { body: 'cross', parent_reply_id: r.id }, asUser(ctx.uuids.user.joon)),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  test('rejects unknown parent_reply_id', async () => {
    const post = await posts.create(
      'dating-event-reviews',
      { body: 'p' },
      asUser(ctx.uuids.user.minseo),
    );
    await expect(
      replies.create(
        post.id,
        { body: 'x', parent_reply_id: '00000000-0000-0000-0000-000000000000' },
        asUser(ctx.uuids.user.joon),
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
