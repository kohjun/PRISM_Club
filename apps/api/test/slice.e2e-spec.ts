import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('Milestone 1 vertical slice (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('walks the full slice', async () => {
    const server = ctx.app.getHttpServer();

    // 1. health is public
    const health = await request(server).get('/v1/health');
    expect(health.status).toBe(200);
    expect(health.body).toEqual({ ok: true });

    // 2. dev users available without auth
    const devUsers = await request(server).get('/v1/dev/users');
    expect(devUsers.status).toBe(200);
    // 3 in M1; 4 since M2 added the `coral` curator persona.
    expect(devUsers.body.length).toBeGreaterThanOrEqual(3);

    // 3. /me without header → 401
    const meAnon = await request(server).get('/v1/me');
    expect(meAnon.status).toBe(401);

    // 4. topic hub bundle as minseo
    const hub = await request(server)
      .get('/v1/categories/love-content/hub')
      .set(HEAD(ctx.uuids.user.minseo));
    expect(hub.status).toBe(200);
    expect(hub.body.blocks).toHaveLength(6);
    expect(hub.body.related_events.length).toBeGreaterThanOrEqual(3);
    expect(hub.body.related_references.length).toBeGreaterThanOrEqual(3);
    expect(hub.body.rooms.length).toBeGreaterThanOrEqual(3);

    // 5. as haneul, search events & upsert event-card (idempotent)
    const search = await request(server)
      .get('/v1/events/search?status=UPCOMING')
      .set(HEAD(ctx.uuids.user.haneul));
    expect(search.status).toBe(200);
    expect(search.body.items.length).toBeGreaterThanOrEqual(3);

    const upsert1 = await request(server)
      .post('/v1/event-cards')
      .set(HEAD(ctx.uuids.user.haneul))
      .send({ external_event_id: 'evt-102' });
    expect(upsert1.status).toBe(201);
    const cardId = upsert1.body.id;

    const upsert2 = await request(server)
      .post('/v1/event-cards')
      .set(HEAD(ctx.uuids.user.haneul))
      .send({ external_event_id: 'evt-102' });
    expect(upsert2.status).toBe(201);
    expect(upsert2.body.id).toBe(cardId);

    // 6. create a reference
    const refRes = await request(server)
      .post('/v1/references')
      .set(HEAD(ctx.uuids.user.haneul))
      .send({
        url: 'https://example.com/r-e2e',
        title: 'e2e reference',
        type: 'ARTICLE',
      });
    expect(refRes.status).toBe(201);
    const refId = refRes.body.id;

    // 7. create a user room with both pins
    const roomRes = await request(server)
      .post('/v1/categories/love-content/rooms')
      .set(HEAD(ctx.uuids.user.haneul))
      .send({
        name: 'e2e room',
        room_type: 'DISCUSSION',
        pinned_event_card_id: cardId,
        pinned_reference_id: refId,
      });
    expect(roomRes.status).toBe(201);
    expect(roomRes.body.origin).toBe('USER');
    expect(roomRes.body.pins).toHaveLength(2);
    const roomSlug = roomRes.body.slug;

    // 8. fetch room detail → both pins resolved
    const roomDetail = await request(server)
      .get(`/v1/rooms/${roomSlug}`)
      .set(HEAD(ctx.uuids.user.haneul));
    expect(roomDetail.status).toBe(200);
    expect(roomDetail.body.pins).toHaveLength(2);

    // 9. create a post with both attachment types
    const postRes = await request(server)
      .post(`/v1/rooms/${roomSlug}/posts`)
      .set(HEAD(ctx.uuids.user.haneul))
      .send({
        body: 'e2e post body',
        attachments: [
          { attachment_type: 'EVENT_CARD', target_id: cardId },
          { attachment_type: 'REFERENCE', target_id: refId },
        ],
      });
    expect(postRes.status).toBe(201);
    expect(postRes.body.attachments).toHaveLength(2);
    const postId = postRes.body.id;

    // 10. timeline lists the post at top
    const timeline = await request(server)
      .get(`/v1/rooms/${roomSlug}/timeline`)
      .set(HEAD(ctx.uuids.user.haneul));
    expect(timeline.status).toBe(200);
    expect(timeline.body.items[0].id).toBe(postId);

    // 11. reply chain: depth-1 OK, depth-2 OK, depth-3 rejected with 400
    const r1 = await request(server)
      .post(`/v1/posts/${postId}/replies`)
      .set(HEAD(ctx.uuids.user.joon))
      .send({ body: 'r1 from joon' });
    expect(r1.status).toBe(201);
    const r1Id = r1.body.id;

    const r2 = await request(server)
      .post(`/v1/posts/${postId}/replies`)
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ body: 'r2 from minseo', parent_reply_id: r1Id });
    expect(r2.status).toBe(201);
    const r2Id = r2.body.id;

    const r3 = await request(server)
      .post(`/v1/posts/${postId}/replies`)
      .set(HEAD(ctx.uuids.user.joon))
      .send({ body: 'r3 should fail', parent_reply_id: r2Id });
    expect(r3.status).toBe(400);

    // 12. reaction toggle: like on, like off, counter math
    const like1 = await request(server)
      .post('/v1/reactions/toggle')
      .set(HEAD(ctx.uuids.user.joon))
      .send({ target_type: 'POST', target_id: postId });
    expect(like1.status).toBe(201);
    expect(like1.body).toEqual({ liked: true, like_count: 1 });

    const like2 = await request(server)
      .post('/v1/reactions/toggle')
      .set(HEAD(ctx.uuids.user.joon))
      .send({ target_type: 'POST', target_id: postId });
    expect(like2.status).toBe(201);
    expect(like2.body).toEqual({ liked: false, like_count: 0 });

    // 13. non-author PATCH → 403; author DELETE → 204; GET after → 404
    const hostilePatch = await request(server)
      .patch(`/v1/posts/${postId}`)
      .set(HEAD(ctx.uuids.user.joon))
      .send({ body: 'hostile edit' });
    expect(hostilePatch.status).toBe(403);

    const del = await request(server)
      .delete(`/v1/posts/${postId}`)
      .set(HEAD(ctx.uuids.user.haneul));
    expect(del.status).toBe(204);

    const afterDel = await request(server)
      .get(`/v1/posts/${postId}`)
      .set(HEAD(ctx.uuids.user.haneul));
    expect(afterDel.status).toBe(404);

    // 14. post-delete: reply list rejects because post is gone
    const replyAfterDel = await request(server)
      .get(`/v1/posts/${postId}/replies`)
      .set(HEAD(ctx.uuids.user.joon));
    expect(replyAfterDel.status).toBe(404);
  });
});
