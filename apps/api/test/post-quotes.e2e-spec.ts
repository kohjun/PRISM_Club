import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

const HEAD = (userId: string) => ({ 'X-User-Id': userId });

/**
 * P4.2 — post quotes (e2e)
 *
 * Verifies the `quoted_post_id` write path persists a `post_quotes`
 * row and that the timeline / detail surface returns the
 * `QuotedPostRef` block. When the original post is deleted, the
 * quoter still surfaces but with `available: false`.
 */
describe('P4.2 — post quotes (e2e)', () => {
  let ctx: TestContext;
  const ROOM = 'dating-event-reviews';

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('quoted_post round-trip — DTO carries the quoted body preview', async () => {
    const original = await request(ctx.app.getHttpServer())
      .post(`/v1/rooms/${ROOM}/posts`)
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ body: 'original post for quoting' });
    expect(original.status).toBe(201);
    const originalId = original.body.id;

    const quoter = await request(ctx.app.getHttpServer())
      .post(`/v1/rooms/${ROOM}/posts`)
      .set(HEAD(ctx.uuids.user.joon))
      .send({
        body: 'quoting that post',
        quoted_post_id: originalId,
      });
    expect(quoter.status).toBe(201);
    expect(quoter.body.quoted_post).toBeTruthy();
    expect(quoter.body.quoted_post.id).toBe(originalId);
    expect(quoter.body.quoted_post.available).toBe(true);
    expect(quoter.body.quoted_post.body_preview).toContain('original post');

    // Round-trip via timeline (post DTO comes through postsToDTOs which
    // batch-fetches the quote refs — different code path than create).
    const tl = await request(ctx.app.getHttpServer())
      .get(`/v1/rooms/${ROOM}/timeline`)
      .set(HEAD(ctx.uuids.user.joon));
    const found = tl.body.items.find(
      (p: { id: string }) => p.id === quoter.body.id,
    );
    expect(found).toBeDefined();
    expect(found.quoted_post?.id).toBe(originalId);
    expect(found.quoted_post.author_nickname).toBeTruthy();
    expect(found.quoted_post.room_slug).toBe(ROOM);
  });

  test('quoted_post.available=false when original is DELETED', async () => {
    const original = await request(ctx.app.getHttpServer())
      .post(`/v1/rooms/${ROOM}/posts`)
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ body: 'will be deleted' });
    const originalId = original.body.id;

    const quoter = await request(ctx.app.getHttpServer())
      .post(`/v1/rooms/${ROOM}/posts`)
      .set(HEAD(ctx.uuids.user.joon))
      .send({ body: 'quoting', quoted_post_id: originalId });
    expect(quoter.status).toBe(201);

    // Delete the original.
    const del = await request(ctx.app.getHttpServer())
      .delete(`/v1/posts/${originalId}`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(del.status).toBe(204);

    // PostQuote.quotedPostId is FK SET NULL — the row stays, the
    // ref turns into the "deleted" sentinel.
    const detail = await request(ctx.app.getHttpServer())
      .get(`/v1/posts/${quoter.body.id}`)
      .set(HEAD(ctx.uuids.user.joon));
    expect(detail.status).toBe(200);
    expect(detail.body.quoted_post).toBeTruthy();
    expect(detail.body.quoted_post.available).toBe(false);
  });

  test('self-quote is rejected', async () => {
    const original = await request(ctx.app.getHttpServer())
      .post(`/v1/rooms/${ROOM}/posts`)
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ body: 'about to try self-quote' });
    expect(original.status).toBe(201);

    // The plan called for a self-quote rejection at the service layer.
    // We give the server two acceptable signals: explicit 400/409, or a
    // create that succeeds but produces no quoted_post (defensive). The
    // common failure mode (a 201 carrying the same post in
    // quoted_post) is what we guard against.
    const sameAuthor = await request(ctx.app.getHttpServer())
      .post(`/v1/rooms/${ROOM}/posts`)
      .set(HEAD(ctx.uuids.user.minseo))
      .send({
        body: 'self quote attempt',
        quoted_post_id: original.body.id,
      });
    if (sameAuthor.status >= 400) {
      expect([400, 403, 409]).toContain(sameAuthor.status);
    } else {
      expect(sameAuthor.body.quoted_post?.id).not.toBe(original.body.id);
    }
  });
});
