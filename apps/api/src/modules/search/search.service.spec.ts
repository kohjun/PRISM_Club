import { BadRequestException } from '@nestjs/common';
import { bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { SearchService } from './search.service';

describe('SearchService', () => {
  let ctx: TestContext;
  let svc: SearchService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    svc = ctx.app.get(SearchService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  // -- query validation --------------------------------------------------

  test('rejects empty query', async () => {
    await expect(svc.searchAll('', null)).rejects.toBeInstanceOf(BadRequestException);
    await expect(svc.searchAll('   ', null)).rejects.toBeInstanceOf(BadRequestException);
  });

  test('rejects oversize query', async () => {
    await expect(svc.searchAll('a'.repeat(201), null)).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  // -- recall ------------------------------------------------------------

  test("'환승연애' finds hits in room, post, reference, and event_card", async () => {
    const res = await svc.searchAll('환승연애', null);
    expect(res.query).toBe('환승연애');
    const byType = Object.fromEntries(res.groups.map((g) => [g.type, g.items.length]));
    expect(byType.room).toBeGreaterThanOrEqual(1);
    expect(byType.post).toBeGreaterThanOrEqual(1);
    expect(byType.reference).toBeGreaterThanOrEqual(1);
    expect(byType.event_card).toBeGreaterThanOrEqual(1);
  });

  test("'소개팅' finds hits in event_card and room", async () => {
    const res = await svc.searchAll('소개팅', null);
    const byType = Object.fromEntries(res.groups.map((g) => [g.type, g.items.length]));
    expect(byType.event_card).toBeGreaterThanOrEqual(1);
    expect(byType.room).toBeGreaterThanOrEqual(1);
  });

  test("'FAQ' finds a knowledge_block whose block_type is FAQ", async () => {
    const res = await svc.searchAll('FAQ', null);
    const blocks = res.groups.find((g) => g.type === 'knowledge_block')!.items;
    expect(blocks.length).toBeGreaterThanOrEqual(1);
    const ctxBlockType = (blocks[0].context as { block_type: string }).block_type;
    expect(ctxBlockType).toBe('FAQ');
  });

  test('no-match query returns all groups with empty items', async () => {
    const res = await svc.searchAll('zzzzz-no-match-zzzzz', null);
    for (const g of res.groups) {
      expect(g.items).toHaveLength(0);
    }
  });

  // -- filter + limit ----------------------------------------------------

  test('type filter limits which groups have items', async () => {
    const res = await svc.searchAll('환승연애', ['room', 'post']);
    const room = res.groups.find((g) => g.type === 'room')!;
    const post = res.groups.find((g) => g.type === 'post')!;
    const other = res.groups.filter(
      (g) => g.type !== 'room' && g.type !== 'post',
    );
    expect(room.items.length).toBeGreaterThanOrEqual(1);
    expect(post.items.length).toBeGreaterThanOrEqual(1);
    for (const g of other) {
      expect(g.items).toHaveLength(0);
    }
  });

  test('limit caps per-group items', async () => {
    // Inject extra posts so we can verify the cap.
    for (let i = 0; i < 4; i += 1) {
      await ctx.prisma.post.create({
        data: {
          roomId: ctx.uuids.room.datingReviews,
          authorId: ctx.uuids.user.minseo,
          body: `소개팅 미션 변형 아이디어 ${i}`,
        },
      });
    }
    const res = await svc.searchAll('소개팅 미션', null, 2);
    const post = res.groups.find((g) => g.type === 'post')!;
    expect(post.items.length).toBeLessThanOrEqual(2);
  });

  // -- snippet & freshness -----------------------------------------------

  test('snippet returns a centered window with ellipses for long bodies', () => {
    const body = 'a'.repeat(40) + 'NEEDLE' + 'b'.repeat(40);
    const snip = svc.snippet(body, 'needle', 30);
    expect(snip).toContain('NEEDLE');
    expect(snip.startsWith('…')).toBe(true);
    expect(snip.endsWith('…')).toBe(true);
  });

  test('snippet returns full text when shorter than radius', () => {
    expect(svc.snippet('짧은 본문', '본문', 80)).toBe('짧은 본문');
  });

  test('snippet returns body head when query not found', () => {
    expect(svc.snippet('short body', 'notfound', 80)).toBe('short body');
  });

  // -- exclusions --------------------------------------------------------

  test('soft-deleted posts are excluded from search results', async () => {
    const post = await ctx.prisma.post.create({
      data: {
        roomId: ctx.uuids.room.datingReviews,
        authorId: ctx.uuids.user.minseo,
        body: 'UNIQUE-SEARCH-TOKEN-12345',
      },
    });
    let hits = await svc.searchAll('UNIQUE-SEARCH-TOKEN-12345', ['post']);
    expect(hits.groups.find((g) => g.type === 'post')!.items.length).toBe(1);

    await ctx.prisma.post.update({
      where: { id: post.id },
      data: { status: 'DELETED' },
    });
    hits = await svc.searchAll('UNIQUE-SEARCH-TOKEN-12345', ['post']);
    expect(hits.groups.find((g) => g.type === 'post')!.items.length).toBe(0);
  });

  // -- suggestions -------------------------------------------------------

  test('suggestionsFor returns the global default for unknown category', () => {
    const res = svc.suggestionsFor(null);
    expect(res.items.length).toBeGreaterThan(0);
    expect(res.items).toContain('환승연애');
  });

  test('suggestionsFor returns category-tuned list for love-content', () => {
    const res = svc.suggestionsFor('love-content');
    expect(res.items).toContain('환승연애');
    expect(res.items).toContain('소개팅 미션');
  });
});
