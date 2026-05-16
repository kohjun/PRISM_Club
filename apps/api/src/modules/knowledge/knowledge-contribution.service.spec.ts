import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { asUser, bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { KnowledgeContributionService } from './knowledge-contribution.service';
import { KnowledgeService } from './knowledge.service';

describe('KnowledgeContributionService', () => {
  let ctx: TestContext;
  let svc: KnowledgeContributionService;
  let knowledge: KnowledgeService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    svc = ctx.app.get(KnowledgeContributionService);
    knowledge = ctx.app.get(KnowledgeService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  // -- submit -----------------------------------------------------------

  test('submit edit-existing happy path with REFERENCE evidence', async () => {
    const result = await svc.submit(
      'love-content',
      {
        target_block_id: ctx.uuids.block.moodTips,
        proposed_block_type: 'MOOD_TIPS',
        proposed_title: '분위기 팁',
        proposed_body: '추가 분위기 팁 본문.',
        evidence_type: 'REFERENCE',
        evidence_target_id: ctx.uuids.reference.selectRuleYoutube,
      },
      asUser(ctx.uuids.user.minseo),
    );
    expect(result.status).toBe('PENDING');
    expect(result.target_block_id).toBe(ctx.uuids.block.moodTips);
    expect(result.evidence_type).toBe('REFERENCE');
    expect(result.evidence).not.toBeNull();
  });

  test('submit propose-new happy path with EVENT_CARD evidence', async () => {
    const result = await svc.submit(
      'love-content',
      {
        target_block_id: null,
        proposed_block_type: 'CHECKLIST',
        proposed_title: '새 체크리스트',
        proposed_body: '체크리스트 본문.',
        evidence_type: 'EVENT_CARD',
        evidence_target_id: ctx.uuids.event.e002,
      },
      asUser(ctx.uuids.user.haneul),
    );
    expect(result.status).toBe('PENDING');
    expect(result.target_block_id).toBeNull();
    expect(result.evidence_type).toBe('EVENT_CARD');
  });

  test('submit rejects unknown target_block_id', async () => {
    await expect(
      svc.submit(
        'love-content',
        {
          target_block_id: '00000000-0000-0000-0000-000000000000',
          proposed_block_type: 'FAQ',
          proposed_title: 't',
          proposed_body: 'b',
        },
        asUser(ctx.uuids.user.minseo),
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  test('submit rejects invalid proposed_block_type', async () => {
    await expect(
      svc.submit(
        'love-content',
        {
          proposed_block_type: 'NOT_A_REAL_TYPE',
          proposed_title: 't',
          proposed_body: 'b',
        },
        asUser(ctx.uuids.user.minseo),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  test('submit rejects evidence_type without evidence_target_id', async () => {
    await expect(
      svc.submit(
        'love-content',
        {
          proposed_block_type: 'FAQ',
          proposed_title: 't',
          proposed_body: 'b',
          evidence_type: 'EVENT_CARD',
        },
        asUser(ctx.uuids.user.minseo),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  test('submit rejects unknown evidence target', async () => {
    await expect(
      svc.submit(
        'love-content',
        {
          proposed_block_type: 'FAQ',
          proposed_title: 't',
          proposed_body: 'b',
          evidence_type: 'REFERENCE',
          evidence_target_id: '00000000-0000-0000-0000-000000000000',
        },
        asUser(ctx.uuids.user.minseo),
      ),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  // -- withdraw ---------------------------------------------------------

  test('withdraw is author-only', async () => {
    const c = await svc.submit(
      'love-content',
      {
        target_block_id: ctx.uuids.block.faq,
        proposed_block_type: 'FAQ',
        proposed_title: 'FAQ',
        proposed_body: 'updated body',
      },
      asUser(ctx.uuids.user.minseo),
    );
    await expect(svc.withdraw(c.id, ctx.uuids.user.joon)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    await svc.withdraw(c.id, ctx.uuids.user.minseo);
    const after = await svc.getDetail(c.id);
    expect(after.status).toBe('WITHDRAWN');
  });

  test('withdraw refuses non-pending contributions', async () => {
    const approvedId = ctx.uuids.contribution.approvedFaqEdit;
    await expect(svc.withdraw(approvedId, ctx.uuids.user.joon)).rejects.toBeInstanceOf(
      ConflictException,
    );
  });

  // -- resolve(APPROVE) on edit-existing -------------------------------

  test('resolve APPROVE on edit-existing updates the block and snapshots prior content', async () => {
    const c = await svc.submit(
      'love-content',
      {
        target_block_id: ctx.uuids.block.warning,
        proposed_block_type: 'WARNING',
        proposed_title: '주의사항',
        proposed_body: '강화된 안전 안내 본문.',
      },
      asUser(ctx.uuids.user.minseo),
    );

    const beforeBlock = await ctx.prisma.knowledgeBlock.findUnique({
      where: { id: ctx.uuids.block.warning },
    });

    const resolved = await svc.resolve(
      c.id,
      { decision: 'APPROVE', note: 'looks good' },
      ctx.uuids.user.coral,
    );
    expect(resolved.status).toBe('APPROVED');
    expect(resolved.snapshot).not.toBeNull();
    expect(resolved.snapshot!.body).toBe(beforeBlock!.body);

    const afterBlock = await ctx.prisma.knowledgeBlock.findUnique({
      where: { id: ctx.uuids.block.warning },
    });
    expect(afterBlock!.body).toBe('강화된 안전 안내 본문.');
  });

  // -- resolve(APPROVE) on propose-new ---------------------------------

  test('resolve APPROVE on propose-new creates a new block at end of hub', async () => {
    const c = await svc.submit(
      'love-content',
      {
        target_block_id: null,
        proposed_block_type: 'CHECKLIST',
        proposed_title: '새 체크리스트',
        proposed_body: '신규 체크리스트 본문.',
      },
      asUser(ctx.uuids.user.haneul),
    );

    const before = await knowledge.getHubByCategorySlug(
      'love-content',
      asUser(ctx.uuids.user.minseo),
    );
    const beforeCount = before.blocks.length;

    await svc.resolve(c.id, { decision: 'APPROVE' }, ctx.uuids.user.coral);

    const after = await knowledge.getHubByCategorySlug(
      'love-content',
      asUser(ctx.uuids.user.minseo),
    );
    expect(after.blocks.length).toBe(beforeCount + 1);
    expect(after.blocks[after.blocks.length - 1].title).toBe('새 체크리스트');
  });

  // -- resolve(REJECT) and REQUEST_CHANGES ------------------------------

  test('resolve REJECT keeps block unchanged and stores curator note', async () => {
    const c = await svc.submit(
      'love-content',
      {
        target_block_id: ctx.uuids.block.overview,
        proposed_block_type: 'OVERVIEW',
        proposed_title: '개요',
        proposed_body: '벼락치기 변경 시도.',
      },
      asUser(ctx.uuids.user.minseo),
    );

    const beforeBlock = await ctx.prisma.knowledgeBlock.findUnique({
      where: { id: ctx.uuids.block.overview },
    });

    const resolved = await svc.resolve(
      c.id,
      { decision: 'REJECT', note: '근거가 부족합니다.' },
      ctx.uuids.user.coral,
    );
    expect(resolved.status).toBe('REJECTED');
    expect(resolved.curator_note).toBe('근거가 부족합니다.');

    const afterBlock = await ctx.prisma.knowledgeBlock.findUnique({
      where: { id: ctx.uuids.block.overview },
    });
    expect(afterBlock!.body).toBe(beforeBlock!.body);
  });

  test('resolve REQUEST_CHANGES maps to NEEDS_CHANGES and leaves block alone', async () => {
    const c = await svc.submit(
      'love-content',
      {
        target_block_id: ctx.uuids.block.overview,
        proposed_block_type: 'OVERVIEW',
        proposed_title: '개요',
        proposed_body: '문장 표현 개선 제안.',
      },
      asUser(ctx.uuids.user.minseo),
    );
    const resolved = await svc.resolve(
      c.id,
      { decision: 'REQUEST_CHANGES', note: '인용을 추가해 주세요.' },
      ctx.uuids.user.coral,
    );
    expect(resolved.status).toBe('NEEDS_CHANGES');
    expect(resolved.curator_note).toBe('인용을 추가해 주세요.');
  });

  test('resolve a second time rejects with 409', async () => {
    const c = await svc.submit(
      'love-content',
      {
        target_block_id: ctx.uuids.block.popularFormat,
        proposed_block_type: 'POPULAR_FORMAT',
        proposed_title: '인기 포맷',
        proposed_body: '두 번 해결 시도.',
      },
      asUser(ctx.uuids.user.minseo),
    );
    await svc.resolve(c.id, { decision: 'REJECT' }, ctx.uuids.user.coral);
    await expect(
      svc.resolve(c.id, { decision: 'APPROVE' }, ctx.uuids.user.coral),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  // -- listMine + listForAdmin ----------------------------------------

  test('listMine filters by contributor', async () => {
    const mine = await svc.listMine(ctx.uuids.user.minseo);
    expect(mine.every((c) => c.contributor.id === ctx.uuids.user.minseo)).toBe(true);
  });

  test('listForAdmin defaults to PENDING when status omitted', async () => {
    const items = await svc.listForAdmin('PENDING', 'love-content');
    expect(items.every((c) => c.status === 'PENDING')).toBe(true);
  });
});
