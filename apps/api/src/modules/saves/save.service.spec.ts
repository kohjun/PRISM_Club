import { asUser, bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { SaveService } from './save.service';

describe('SaveService', () => {
  let ctx: TestContext;
  let svc: SaveService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    svc = ctx.app.get(SaveService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('toggle save POST creates row and increments bookmarkCount', async () => {
    const result = await svc.toggle(
      { target_type: 'POST', target_id: ctx.uuids.post.joonQuestion },
      asUser(ctx.uuids.user.joon),
    );
    expect(result.saved).toBe(true);

    const post = await ctx.prisma.post.findUnique({ where: { id: ctx.uuids.post.joonQuestion } });
    expect(post?.bookmarkCount).toBeGreaterThanOrEqual(1);
  });

  test('toggle unsave POST removes row and decrements bookmarkCount', async () => {
    const viewer = asUser(ctx.uuids.user.haneul);
    // Save first
    await svc.toggle({ target_type: 'POST', target_id: ctx.uuids.post.haneulIdea }, viewer);
    const postBefore = await ctx.prisma.post.findUnique({ where: { id: ctx.uuids.post.haneulIdea } });
    const countBefore = postBefore?.bookmarkCount ?? 0;

    // Unsave
    const result = await svc.toggle({ target_type: 'POST', target_id: ctx.uuids.post.haneulIdea }, viewer);
    expect(result.saved).toBe(false);
    const postAfter = await ctx.prisma.post.findUnique({ where: { id: ctx.uuids.post.haneulIdea } });
    expect(postAfter?.bookmarkCount).toBe(countBefore - 1);
  });

  test('toggle save REFERENCE creates row with no bookmarkCount side effect', async () => {
    const result = await svc.toggle(
      { target_type: 'REFERENCE', target_id: ctx.uuids.reference.selectRuleYoutube },
      asUser(ctx.uuids.user.joon),
    );
    expect(result.saved).toBe(true);
  });

  test('listForUser with type filter returns correct subset', async () => {
    const all = await svc.listForUser(asUser(ctx.uuids.user.minseo));
    const posts = await svc.listForUser(asUser(ctx.uuids.user.minseo), 'POST');
    const refs = await svc.listForUser(asUser(ctx.uuids.user.minseo), 'REFERENCE');

    expect(all.items.length).toBeGreaterThanOrEqual(2);
    expect(posts.items.every((i) => i.target_type === 'POST')).toBe(true);
    expect(refs.items.every((i) => i.target_type === 'REFERENCE')).toBe(true);
    expect(posts.items.length + refs.items.length).toBe(all.items.length);
  });
});
