import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

const HEAD = (userId: string) => ({ 'X-User-Id': userId });

/**
 * P4.4 — saved collections (e2e)
 *
 * Verifies the create / move / filter / delete loop on
 * `/v1/me/collections` + `/v1/me/saves/:saveId/move` and confirms the
 * `collection_id` filter on `/v1/me/saves` honours both the explicit
 * UUID and the `__none__` sentinel.
 */
describe('P4.4 — saved collections (e2e)', () => {
  let ctx: TestContext;
  // Re-use a known seeded post so we don't need to create one per test.
  const SAVE_TARGET = '88800001-0000-0000-0000-000000000001';

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  beforeEach(async () => {
    // Clean per-user collections + saves so the assertions stay stable
    // regardless of which test ran first.
    await ctx.prisma.savedItem.deleteMany({
      where: { userId: ctx.uuids.user.minseo },
    });
    await ctx.prisma.savedCollection.deleteMany({
      where: { userId: ctx.uuids.user.minseo },
    });
  });

  test('create + move + filter + cleanup loop', async () => {
    const created = await request(ctx.app.getHttpServer())
      .post('/v1/me/collections')
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ name: 'e2e folder' });
    expect(created.status).toBe(200);
    const colId = created.body.id;
    expect(colId).toBeTruthy();
    expect(created.body.item_count).toBe(0);

    // Save a post so we have a saved_items row to move.
    const save = await request(ctx.app.getHttpServer())
      .post('/v1/me/saves')
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ target_type: 'POST', target_id: SAVE_TARGET });
    expect(save.status).toBe(200);
    expect(save.body.saved).toBe(true);

    // Locate the save row id.
    const list = await request(ctx.app.getHttpServer())
      .get('/v1/me/saves?type=POST')
      .set(HEAD(ctx.uuids.user.minseo));
    const saveRow = list.body.items.find(
      (i: { target_id: string }) => i.target_id === SAVE_TARGET,
    );
    expect(saveRow).toBeDefined();
    expect(saveRow.collection_id).toBeNull();

    // Move into the new collection.
    const move = await request(ctx.app.getHttpServer())
      .post(`/v1/me/saves/${saveRow.id}/move`)
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ collection_id: colId });
    expect(move.status).toBe(200);

    // Filter by collection — should return exactly that item.
    const filtered = await request(ctx.app.getHttpServer())
      .get(`/v1/me/saves?collection_id=${colId}`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(filtered.status).toBe(200);
    expect(filtered.body.items).toHaveLength(1);
    expect(filtered.body.items[0].id).toBe(saveRow.id);
    expect(filtered.body.items[0].collection_id).toBe(colId);

    // __none__ sentinel — same user, no items left uncollected.
    const orphans = await request(ctx.app.getHttpServer())
      .get('/v1/me/saves?collection_id=__none__')
      .set(HEAD(ctx.uuids.user.minseo));
    expect(orphans.status).toBe(200);
    expect(orphans.body.items).toHaveLength(0);

    // Delete the collection — the save survives but goes back to null.
    const del = await request(ctx.app.getHttpServer())
      .delete(`/v1/me/collections/${colId}`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(del.status).toBe(200);

    const afterDelete = await request(ctx.app.getHttpServer())
      .get('/v1/me/saves?collection_id=__none__')
      .set(HEAD(ctx.uuids.user.minseo));
    expect(afterDelete.body.items).toHaveLength(1);
    expect(afterDelete.body.items[0].id).toBe(saveRow.id);
    expect(afterDelete.body.items[0].collection_id).toBeNull();
  });

  test('duplicate collection name returns 409', async () => {
    const first = await request(ctx.app.getHttpServer())
      .post('/v1/me/collections')
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ name: 'duplicate' });
    expect(first.status).toBe(200);

    const second = await request(ctx.app.getHttpServer())
      .post('/v1/me/collections')
      .set(HEAD(ctx.uuids.user.minseo))
      .send({ name: 'duplicate' });
    expect(second.status).toBe(409);
  });
});
