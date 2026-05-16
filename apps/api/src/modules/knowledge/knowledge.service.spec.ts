import { NotFoundException } from '@nestjs/common';
import { bootstrapTestApp, teardownTestApp, TestContext } from '../../../test/test-app';
import { KnowledgeService } from './knowledge.service';

describe('KnowledgeService', () => {
  let ctx: TestContext;
  let knowledge: KnowledgeService;

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    knowledge = ctx.app.get(KnowledgeService);
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('getHubByCategorySlug returns the full bundle for love-content', async () => {
    const bundle = await knowledge.getHubByCategorySlug('love-content');
    expect(bundle.category.slug).toBe('love-content');
    expect(bundle.hub).not.toBeNull();
    expect(bundle.blocks).toHaveLength(6);
    expect(bundle.signals).toHaveLength(3);
    expect(bundle.related_events.length).toBeGreaterThanOrEqual(3);
    expect(bundle.related_references.length).toBeGreaterThanOrEqual(3);
    expect(bundle.rooms.length).toBeGreaterThanOrEqual(3);
  });

  test('unknown category throws NotFound', async () => {
    await expect(knowledge.getHubByCategorySlug('does-not-exist')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
