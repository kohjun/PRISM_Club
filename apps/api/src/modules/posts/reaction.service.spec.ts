import { NotFoundException } from '@nestjs/common';
import { bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { ReactionService } from './reaction.service';
import { PostService } from './post.service';

describe('ReactionService', () => {
  let ctx: TestContext;
  let reactions: ReactionService;
  let posts: PostService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    reactions = ctx.app.get(ReactionService);
    posts = ctx.app.get(PostService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('toggle creates then deletes; counter goes 0 → 1 → 0', async () => {
    const post = await posts.create(
      'dating-event-reviews',
      { body: 'react-test' },
      ctx.uuids.user.minseo,
    );

    const first = await reactions.toggleLike(ctx.uuids.user.joon, 'POST', post.id);
    expect(first.liked).toBe(true);
    expect(first.like_count).toBe(1);

    const second = await reactions.toggleLike(ctx.uuids.user.joon, 'POST', post.id);
    expect(second.liked).toBe(false);
    expect(second.like_count).toBe(0);
  });

  test('two distinct users each contribute one like', async () => {
    const post = await posts.create(
      'dating-event-reviews',
      { body: 'two-users-react' },
      ctx.uuids.user.minseo,
    );

    const a = await reactions.toggleLike(ctx.uuids.user.joon, 'POST', post.id);
    expect(a.like_count).toBe(1);

    const b = await reactions.toggleLike(ctx.uuids.user.haneul, 'POST', post.id);
    expect(b.like_count).toBe(2);

    const c = await reactions.toggleLike(ctx.uuids.user.joon, 'POST', post.id);
    expect(c.like_count).toBe(1);
  });

  test('rejects unknown target', async () => {
    await expect(
      reactions.toggleLike(
        ctx.uuids.user.joon,
        'POST',
        '00000000-0000-0000-0000-000000000000',
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
