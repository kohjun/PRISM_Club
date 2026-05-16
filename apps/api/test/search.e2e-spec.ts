import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('Search (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('search and suggestions flow', async () => {
    const server = ctx.app.getHttpServer();

    // 1. Empty q → 400
    const empty = await request(server)
      .get('/v1/search?q=')
      .set(HEAD(ctx.uuids.user.minseo));
    expect(empty.status).toBe(400);

    // 2. Real query as a member → 200 with grouped hits
    const real = await request(server)
      .get('/v1/search')
      .query({ q: '환승연애' })
      .set(HEAD(ctx.uuids.user.minseo));
    expect(real.status).toBe(200);
    expect(real.body.query).toBe('환승연애');
    const groups = real.body.groups as { type: string; items: unknown[] }[];
    expect(groups.length).toBe(6);
    const byType = Object.fromEntries(groups.map((g) => [g.type, g.items.length]));
    expect(byType.room).toBeGreaterThanOrEqual(1);
    expect(byType.post).toBeGreaterThanOrEqual(1);
    expect(byType.reference).toBeGreaterThanOrEqual(1);
    expect(byType.event_card).toBeGreaterThanOrEqual(1);

    // 3. Type filter limits result groups
    const filtered = await request(server)
      .get('/v1/search')
      .query({ q: '환승연애', types: 'room,post' })
      .set(HEAD(ctx.uuids.user.minseo));
    expect(filtered.status).toBe(200);
    const groupsF = filtered.body.groups as { type: string; items: unknown[] }[];
    for (const g of groupsF) {
      if (g.type === 'room' || g.type === 'post') {
        expect(g.items.length).toBeGreaterThanOrEqual(1);
      } else {
        expect(g.items).toHaveLength(0);
      }
    }

    // 4. No-match → all groups empty
    const noMatch = await request(server)
      .get('/v1/search')
      .query({ q: 'zzzzz-no-match-zzzzz' })
      .set(HEAD(ctx.uuids.user.minseo));
    expect(noMatch.status).toBe(200);
    for (const g of noMatch.body.groups) {
      expect(g.items).toHaveLength(0);
    }

    // 5. Create a fresh post → it appears in search results
    const createdPost = await request(server)
      .post(`/v1/rooms/dating-event-reviews/posts`)
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ body: 'UNIQUE-E2E-SEARCH-PHRASE-소개팅-미션' });
    expect(createdPost.status).toBe(201);
    const postId = createdPost.body.id;

    const findFresh = await request(server)
      .get('/v1/search')
      .query({ q: 'UNIQUE-E2E-SEARCH-PHRASE' })
      .set(HEAD(ctx.uuids.user.minseo));
    const postHits = findFresh.body.groups.find(
      (g: { type: string }) => g.type === 'post',
    ).items;
    expect(postHits.length).toBeGreaterThanOrEqual(1);
    expect(postHits.map((h: { id: string }) => h.id)).toContain(postId);

    // 6. Soft-delete the post → it disappears from search
    const del = await request(server)
      .delete(`/v1/posts/${postId}`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(del.status).toBe(204);

    const afterDelete = await request(server)
      .get('/v1/search')
      .query({ q: 'UNIQUE-E2E-SEARCH-PHRASE' })
      .set(HEAD(ctx.uuids.user.minseo));
    const postHitsAfter = afterDelete.body.groups.find(
      (g: { type: string }) => g.type === 'post',
    ).items;
    expect(postHitsAfter.length).toBe(0);

    // 7. Suggestions returns a non-empty list
    const sug = await request(server)
      .get('/v1/search/suggestions')
      .set(HEAD(ctx.uuids.user.minseo));
    expect(sug.status).toBe(200);
    expect(Array.isArray(sug.body.items)).toBe(true);
    expect(sug.body.items.length).toBeGreaterThan(0);
  });
});
