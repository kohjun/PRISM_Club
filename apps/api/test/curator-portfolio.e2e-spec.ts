import request from 'supertest';
import { bootstrapTestApp, TestContext, teardownTestApp } from './test-app';

describe('P6.10 — curator portfolio (e2e)', () => {
  let ctx: TestContext;
  const HEAD = (userId: string) => ({ 'X-User-Id': userId });

  beforeAll(async () => {
    ctx = await bootstrapTestApp();
    // Seed has no ReferenceSourceRule attributed to a user (migration
    // rules carry createdBy=null), so plant one authored by coral the
    // curator to exercise the source-rules section.
    await ctx.prisma.referenceSourceRule.create({
      data: {
        domainPattern: 'e2e-curator-portfolio.example.com',
        tier: 'TRUSTED',
        note: 'planted by the P6.10 e2e',
        createdBy: ctx.uuids.user.coral,
      },
    });
  });

  afterAll(async () => {
    await teardownTestApp(ctx);
  });

  test('coral (CURATOR) portfolio lists resolved contribution + authored source rule', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get(`/v1/profiles/${ctx.uuids.user.coral}/curator-portfolio`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(res.status).toBe(200);
    expect(res.body.user_id).toBe(ctx.uuids.user.coral);
    expect(res.body.is_curator).toBe(true);

    // Seed: joon's FAQ edit was APPROVED, resolvedBy=coral.
    const contributions = res.body.resolved_contributions as Array<
      Record<string, unknown>
    >;
    const faq = contributions.find((c) => c.title === 'FAQ');
    expect(faq).toBeDefined();
    expect(faq!.category_slug).toBe('love-content');
    expect(typeof faq!.resolved_at).toBe('string');

    // The source rule planted in beforeAll.
    const rules = res.body.source_rules as Array<Record<string, unknown>>;
    const planted = rules.find(
      (r) => r.domain_pattern === 'e2e-curator-portfolio.example.com',
    );
    expect(planted).toBeDefined();
    expect(planted!.tier).toBe('TRUSTED');
  });

  test('reputation field is always present (object or null)', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get(`/v1/profiles/${ctx.uuids.user.coral}/curator-portfolio`)
      .set(HEAD(ctx.uuids.user.coral));
    expect(res.status).toBe(200);
    expect('reputation' in res.body).toBe(true);
  });

  test('a non-curator returns is_curator=false with empty lists', async () => {
    // joon is the contributor (a plain member), not a resolver.
    const res = await request(ctx.app.getHttpServer())
      .get(`/v1/profiles/${ctx.uuids.user.joon}/curator-portfolio`)
      .set(HEAD(ctx.uuids.user.minseo));
    expect(res.status).toBe(200);
    expect(res.body.is_curator).toBe(false);
    expect(res.body.resolved_contributions).toEqual([]);
    expect(res.body.source_rules).toEqual([]);
  });

  test('unknown user → 404', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get('/v1/profiles/00000000-0000-0000-0000-000000000000/curator-portfolio')
      .set(HEAD(ctx.uuids.user.minseo));
    expect(res.status).toBe(404);
  });
});
