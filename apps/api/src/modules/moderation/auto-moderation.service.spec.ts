import { AutoModerationService } from './auto-moderation.service';
import { PrismaService } from '../../shared/prisma.service';
import { TrustScoreService, TrustTier } from '../../shared/trust-score.service';
import { MetricsService } from '../../shared/metrics.service';
import { AnalyticsService } from '../analytics/analytics.service';
import { Viewer } from '../../shared/access-control.service';

type RuleRow = { params: unknown; enabled: boolean } | null;

function makeService(opts: {
  rule?: RuleRow;
  recentBodies?: string[];
  tier?: TrustTier;
}): AutoModerationService {
  const bodies = (opts.recentBodies ?? []).map((b) => ({ body: b }));
  const prisma = {
    autoModerationRule: { findUnique: async () => opts.rule ?? null },
    post: { findMany: async () => bodies },
    dmMessage: { findMany: async () => bodies },
    report: { count: async () => 0 },
  } as unknown as PrismaService;
  const trust = {
    syncTierFor: () => opts.tier ?? 'MEMBER',
  } as unknown as TrustScoreService;
  const metrics = { inc: () => undefined } as unknown as MetricsService;
  const analytics = { record: () => undefined } as unknown as AnalyticsService;
  return new AutoModerationService(prisma, trust, metrics, analytics);
}

const viewer = { id: 'u1', roles: ['MEMBER'] } as Viewer & { id: string };

describe('AutoModerationService', () => {
  const original = process.env.AUTO_MODERATION_ENFORCE;
  afterEach(() => {
    if (original === undefined) delete process.env.AUTO_MODERATION_ENFORCE;
    else process.env.AUTO_MODERATION_ENFORCE = original;
  });

  describe('evaluatePostBeforeCreate', () => {
    it('does NOT fire when the rule row is disabled (kill switch)', async () => {
      process.env.AUTO_MODERATION_ENFORCE = '1';
      const svc = makeService({
        rule: { params: { threshold: 2 }, enabled: false },
        recentBodies: ['spam', 'spam', 'spam'],
      });
      const d = await svc.evaluatePostBeforeCreate({ viewer, body: 'spam' });
      expect(d.hide).toBe(false);
    });

    it('no-ops when no rule row exists', async () => {
      process.env.AUTO_MODERATION_ENFORCE = '1';
      const svc = makeService({ rule: null, recentBodies: ['spam', 'spam'] });
      const d = await svc.evaluatePostBeforeCreate({ viewer, body: 'spam' });
      expect(d.hide).toBe(false);
    });

    it('hides on duplicate ≥ threshold when enabled + enforce', async () => {
      process.env.AUTO_MODERATION_ENFORCE = '1';
      const svc = makeService({
        rule: { params: { threshold: 2 }, enabled: true },
        recentBodies: ['spam', 'spam'],
      });
      const d = await svc.evaluatePostBeforeCreate({ viewer, body: 'spam' });
      expect(d.hide).toBe(true);
      expect(d.reason).toBe('DUPLICATE_POST_HASH');
    });

    it('shadow mode (enforce unset): records but does not hide', async () => {
      delete process.env.AUTO_MODERATION_ENFORCE;
      const svc = makeService({
        rule: { params: { threshold: 2 }, enabled: true },
        recentBodies: ['spam', 'spam'],
      });
      const d = await svc.evaluatePostBeforeCreate({ viewer, body: 'spam' });
      expect(d.hide).toBe(false);
    });

    it('bypasses TRUSTED/PLANNER tiers', async () => {
      process.env.AUTO_MODERATION_ENFORCE = '1';
      const svc = makeService({
        rule: { params: { threshold: 2 }, enabled: true },
        recentBodies: ['spam', 'spam'],
        tier: 'TRUSTED',
      });
      const d = await svc.evaluatePostBeforeCreate({ viewer, body: 'spam' });
      expect(d.hide).toBe(false);
    });
  });

  describe('evaluateDmMessageBeforeCreate', () => {
    it('enforces with defaults when NO rule row exists (day-1 on)', async () => {
      delete process.env.AUTO_MODERATION_ENFORCE; // DM ignores the shadow flag
      const svc = makeService({ rule: null, recentBodies: ['hi', 'hi'] });
      const d = await svc.evaluateDmMessageBeforeCreate({
        viewer,
        channelId: 'c1',
        body: 'hi',
      });
      expect(d.hide).toBe(true);
      expect(d.reason).toBe('DUPLICATE_DM_HASH');
    });

    it('an explicit disabled rule stops DM enforcement', async () => {
      const svc = makeService({
        rule: { params: {}, enabled: false },
        recentBodies: ['hi', 'hi'],
      });
      const d = await svc.evaluateDmMessageBeforeCreate({
        viewer,
        channelId: 'c1',
        body: 'hi',
      });
      expect(d.hide).toBe(false);
    });

    it('does not hide below threshold', async () => {
      const svc = makeService({ rule: null, recentBodies: ['hi'] });
      const d = await svc.evaluateDmMessageBeforeCreate({
        viewer,
        channelId: 'c1',
        body: 'hi',
      });
      expect(d.hide).toBe(false);
    });
  });
});
