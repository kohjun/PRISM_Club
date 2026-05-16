import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { PostService } from './post.service';

describe('PostService', () => {
  let ctx: TestContext;
  let posts: PostService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    posts = ctx.app.get(PostService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('create writes both attachment types in one transaction', async () => {
    const post = await posts.create(
      'dating-event-reviews',
      {
        body: 'attachment test',
        attachments: [
          { attachment_type: 'EVENT_CARD', target_id: ctx.uuids.event.e001 },
          { attachment_type: 'REFERENCE', target_id: ctx.uuids.reference.selectRuleYoutube },
        ],
      },
      ctx.uuids.user.minseo,
    );
    expect(post.attachments).toHaveLength(2);
    const types = post.attachments.map((a) => a.attachment_type).sort();
    expect(types).toEqual(['EVENT_CARD', 'REFERENCE']);
  });

  test('rejects unknown attachment target', async () => {
    await expect(
      posts.create(
        'dating-event-reviews',
        {
          body: 'bad attachment',
          attachments: [
            {
              attachment_type: 'EVENT_CARD',
              target_id: '00000000-0000-0000-0000-000000000000',
            },
          ],
        },
        ctx.uuids.user.minseo,
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  test('update is author-only', async () => {
    const post = await posts.create(
      'dating-event-reviews',
      { body: 'mine' },
      ctx.uuids.user.minseo,
    );
    await expect(
      posts.update(post.id, 'hostile edit', ctx.uuids.user.joon),
    ).rejects.toBeInstanceOf(ForbiddenException);
    const ok = await posts.update(post.id, 'self edit', ctx.uuids.user.minseo);
    expect(ok.body).toBe('self edit');
  });

  test('softDelete hides post from getById', async () => {
    const post = await posts.create(
      'dating-event-reviews',
      { body: 'transient' },
      ctx.uuids.user.minseo,
    );
    await posts.softDelete(post.id, ctx.uuids.user.minseo);
    await expect(posts.getById(post.id, ctx.uuids.user.minseo)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
