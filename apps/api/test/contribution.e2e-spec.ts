import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('Knowledge contribution flow (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('walks member→curator→hub-update', async () => {
    const server = ctx.app.getHttpServer();

    // 1. minseo submits an edit to MOOD_TIPS with Reference evidence
    const edit = await request(server)
      .post('/v1/categories/love-content/knowledge-contributions')
      .set(HEAD(ctx.uuids.user.minseo))
      .send({
        target_block_id: ctx.uuids.block.moodTips,
        proposed_block_type: 'MOOD_TIPS',
        proposed_title: '분위기 팁',
        proposed_body: '도입부 5분 어색함 완화 + 음악 볼륨 조정 디테일 추가 본문.',
        evidence_type: 'REFERENCE',
        evidence_target_id: ctx.uuids.reference.selectRuleYoutube,
      });
    expect(edit.status).toBe(201);
    expect(edit.body.status).toBe('PENDING');
    const editId = edit.body.id;

    // 2. minseo submits a propose-new CHECKLIST with EventCard evidence
    const newBlock = await request(server)
      .post('/v1/categories/love-content/knowledge-contributions')
      .set(HEAD(ctx.uuids.user.minseo))
      .send({
        target_block_id: null,
        proposed_block_type: 'CHECKLIST',
        proposed_title: '신규 체크리스트',
        proposed_body: '신규 체크리스트 본문.',
        evidence_type: 'EVENT_CARD',
        evidence_target_id: ctx.uuids.event.e002,
      });
    expect(newBlock.status).toBe(201);
    const newBlockId = newBlock.body.id;

    // 3. minseo lists her contributions
    const mine = await request(server)
      .get('/v1/me/contributions')
      .set(HEAD(ctx.uuids.user.minseo));
    expect(mine.status).toBe(200);
    expect(mine.body.items.length).toBeGreaterThanOrEqual(2);

    // 4. joon (non-curator) is denied admin list
    const denied = await request(server)
      .get('/v1/admin/knowledge-contributions')
      .set(HEAD(ctx.uuids.user.joon));
    expect(denied.status).toBe(403);

    // 5. coral (CURATOR) lists pending — includes the two new + seeded pending
    const queue = await request(server)
      .get('/v1/admin/knowledge-contributions?status=PENDING')
      .set(HEAD(ctx.uuids.user.coral));
    expect(queue.status).toBe(200);
    expect(queue.body.items.length).toBeGreaterThanOrEqual(2);
    const queueIds = queue.body.items.map((it: any) => it.id);
    expect(queueIds).toContain(editId);
    expect(queueIds).toContain(newBlockId);

    // 6. coral approves the edit
    const approveEdit = await request(server)
      .post(`/v1/admin/knowledge-contributions/${editId}/resolve`)
      .set(HEAD(ctx.uuids.user.coral))
      .send({ decision: 'APPROVE', note: '좋은 보완입니다.' });
    expect(approveEdit.status).toBe(201);
    expect(approveEdit.body.status).toBe('APPROVED');
    expect(approveEdit.body.snapshot).not.toBeNull();

    // 7. Hub fetch shows the MOOD_TIPS block reflects the proposed body
    const hubAfterEdit = await request(server)
      .get('/v1/categories/love-content/hub')
      .set(HEAD(ctx.uuids.user.minseo));
    expect(hubAfterEdit.status).toBe(200);
    const moodBlock = hubAfterEdit.body.blocks.find(
      (b: any) => b.id === ctx.uuids.block.moodTips,
    );
    expect(moodBlock.body).toContain('음악 볼륨 조정');

    // 8. Block count BEFORE approving the new-block proposal
    const hubBeforeNew = await request(server)
      .get('/v1/categories/love-content/hub')
      .set(HEAD(ctx.uuids.user.minseo));
    const beforeCount = hubBeforeNew.body.blocks.length;

    // 9. coral approves the new-block proposal
    const approveNew = await request(server)
      .post(`/v1/admin/knowledge-contributions/${newBlockId}/resolve`)
      .set(HEAD(ctx.uuids.user.coral))
      .send({ decision: 'APPROVE' });
    expect(approveNew.status).toBe(201);
    expect(approveNew.body.status).toBe('APPROVED');

    // 10. Hub now has one more block
    const hubAfterNew = await request(server)
      .get('/v1/categories/love-content/hub')
      .set(HEAD(ctx.uuids.user.minseo));
    expect(hubAfterNew.body.blocks.length).toBe(beforeCount + 1);
    expect(
      hubAfterNew.body.blocks.find((b: any) => b.title === '신규 체크리스트'),
    ).toBeDefined();

    // 11. coral rejects the seed's existing pending MOOD_TIPS edit
    const seededPendingId = ctx.uuids.contribution.pendingMoodTipsEdit;
    const reject = await request(server)
      .post(`/v1/admin/knowledge-contributions/${seededPendingId}/resolve`)
      .set(HEAD(ctx.uuids.user.coral))
      .send({ decision: 'REJECT', note: '중복된 제안입니다.' });
    expect(reject.status).toBe(201);
    expect(reject.body.status).toBe('REJECTED');
    expect(reject.body.curator_note).toBe('중복된 제안입니다.');

    // 12. minseo's list now reflects updated statuses
    const mineAfter = await request(server)
      .get('/v1/me/contributions')
      .set(HEAD(ctx.uuids.user.minseo));
    const editAfter = mineAfter.body.items.find((c: any) => c.id === editId);
    expect(editAfter.status).toBe('APPROVED');

    // 13. joon cannot withdraw minseo's contribution
    const otherWithdraw = await request(server)
      .delete(`/v1/knowledge-contributions/${editId}`)
      .set(HEAD(ctx.uuids.user.joon));
    expect(otherWithdraw.status).toBe(403);

    // 14. coral cannot resolve an already-resolved contribution
    const reresolve = await request(server)
      .post(`/v1/admin/knowledge-contributions/${editId}/resolve`)
      .set(HEAD(ctx.uuids.user.coral))
      .send({ decision: 'APPROVE' });
    expect(reresolve.status).toBe(409);
  });
});
