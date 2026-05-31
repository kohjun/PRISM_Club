import { Injectable, Logger } from '@nestjs/common';
import * as crypto from 'crypto';
import { PrismaService } from '../../shared/prisma.service';
import { TrustScoreService } from '../../shared/trust-score.service';
import { MetricsService } from '../../shared/metrics.service';
import { Viewer } from '../../shared/access-control.service';
import { AnalyticsService } from '../analytics/analytics.service';

interface RulesParams {
  window_hours?: number;
  threshold?: number;
}

interface PostDecision {
  hide: boolean;
  reason: string | null;
}

interface ReportDecision {
  dismiss: boolean;
  reason: string | null;
}

/**
 * P5.2 auto-moderation gate.
 *
 * Two evaluators are wired into the create paths:
 *   - evaluatePostBeforeCreate — returns {hide, reason}; PostService
 *     stamps the post HIDDEN + auto_moderation_reason when hide=true.
 *     Only NEW/MEMBER tiers are evaluated; TRUSTED+ bypass.
 *   - evaluateReportBeforeCreate — returns {dismiss, reason};
 *     ReportService records the report with status=RESOLVED and
 *     auto_dismissed_reason when dismiss=true. Again, only
 *     NEW/MEMBER are subject to flood checks.
 *
 * Shadow mode (`AUTO_MODERATION_ENFORCE=0`): always returns
 * {hide:false} / {dismiss:false} but records the metric and analytics
 * event so we can see what *would* have been moderated before
 * enforcing. Flip `AUTO_MODERATION_ENFORCE=1` to start hiding.
 */
@Injectable()
export class AutoModerationService {
  private readonly log = new Logger(AutoModerationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly trust: TrustScoreService,
    private readonly metrics: MetricsService,
    private readonly analytics: AnalyticsService,
  ) {}

  async evaluatePostBeforeCreate(opts: {
    viewer: Viewer & { id: string };
    body: string;
  }): Promise<PostDecision> {
    const tier = this.trust.syncTierFor(opts.viewer);
    if (tier === 'TRUSTED' || tier === 'PLANNER') {
      return { hide: false, reason: null };
    }
    const rule = await this._loadRule('DUPLICATE_POST_HASH');
    if (!rule) return { hide: false, reason: null };
    const params = rule.params as RulesParams;
    const windowHours = params.window_hours ?? 24;
    const threshold = params.threshold ?? 2;

    const bodyHash = this._normalizedHash(opts.body);
    const since = new Date(Date.now() - windowHours * 60 * 60 * 1000);

    // Look up the user's recent posts (limit scan to a reasonable
    // window) and compare normalized hashes in-process.
    const recent = await this.prisma.post.findMany({
      where: {
        authorId: opts.viewer.id,
        createdAt: { gte: since },
      },
      select: { body: true },
      take: 50,
    });
    const matches = recent.filter(
      (r) => this._normalizedHash(r.body) === bodyHash,
    ).length;
    if (matches < threshold) {
      return { hide: false, reason: null };
    }

    this.metrics.inc('auto_moderation.hide.would');
    this.analytics.record({
      actorId: opts.viewer.id,
      eventType: 'AUTO_MODERATION_TRIGGERED',
      payload: { kind: 'DUPLICATE_POST_HASH', matches, threshold },
    });
    if (process.env.AUTO_MODERATION_ENFORCE !== '1') {
      this.log.debug(
        `shadow: would hide duplicate post by user=${opts.viewer.id} matches=${matches}`,
      );
      return { hide: false, reason: null };
    }
    return { hide: true, reason: 'DUPLICATE_POST_HASH' };
  }

  async evaluateReportBeforeCreate(opts: {
    viewer: Viewer & { id: string };
  }): Promise<ReportDecision> {
    const tier = this.trust.syncTierFor(opts.viewer);
    if (tier === 'TRUSTED' || tier === 'PLANNER') {
      return { dismiss: false, reason: null };
    }
    const rule = await this._loadRule('REPORT_FLOOD');
    if (!rule) return { dismiss: false, reason: null };
    const params = rule.params as RulesParams;
    const windowHours = params.window_hours ?? 1;
    const threshold = params.threshold ?? 10;

    const since = new Date(Date.now() - windowHours * 60 * 60 * 1000);
    const recentCount = await this.prisma.report.count({
      where: { reporterId: opts.viewer.id, createdAt: { gte: since } },
    });
    if (recentCount < threshold) {
      return { dismiss: false, reason: null };
    }

    this.metrics.inc('auto_moderation.dismiss.would');
    this.analytics.record({
      actorId: opts.viewer.id,
      eventType: 'AUTO_MODERATION_TRIGGERED',
      payload: { kind: 'REPORT_FLOOD', count: recentCount, threshold },
    });
    if (process.env.AUTO_MODERATION_ENFORCE !== '1') {
      return { dismiss: false, reason: null };
    }
    return { dismiss: true, reason: 'REPORT_FLOOD' };
  }

  /**
   * P6.9 — DM dup-spam gate. Unlike the post/report evaluators this
   * ENFORCES day-1 (no AUTO_MODERATION_ENFORCE shadow gate) and applies
   * to every tier, because DM is the highest-abuse surface and an
   * identical body repeated within one channel is an unambiguous spam
   * signal. Falls back to defaults when no rule row is seeded. Default
   * threshold 2 = the 3rd identical message is hidden (matches the
   * DUPLICATE_POST_HASH semantics).
   */
  async evaluateDmMessageBeforeCreate(opts: {
    viewer: Viewer & { id: string };
    channelId: string;
    body: string;
  }): Promise<PostDecision> {
    const rule = await this._loadRule('DUPLICATE_DM_HASH');
    const params = (rule?.params as RulesParams) ?? {};
    const windowHours = params.window_hours ?? 24;
    const threshold = params.threshold ?? 2;

    const bodyHash = this._normalizedHash(opts.body);
    const since = new Date(Date.now() - windowHours * 60 * 60 * 1000);
    const recent = await this.prisma.dmMessage.findMany({
      where: {
        senderId: opts.viewer.id,
        channelId: opts.channelId,
        createdAt: { gte: since },
      },
      select: { body: true },
      take: 50,
    });
    const matches = recent.filter(
      (r) => this._normalizedHash(r.body) === bodyHash,
    ).length;
    if (matches < threshold) {
      return { hide: false, reason: null };
    }
    this.metrics.inc('auto_moderation.dm_hide');
    this.analytics.record({
      actorId: opts.viewer.id,
      eventType: 'AUTO_MODERATION_TRIGGERED',
      payload: { kind: 'DUPLICATE_DM_HASH', matches, threshold },
    });
    return { hide: true, reason: 'DUPLICATE_DM_HASH' };
  }

  private async _loadRule(kind: string): Promise<{
    params: unknown;
  } | null> {
    return this.prisma.autoModerationRule.findUnique({
      where: { kind },
      select: { params: true, enabled: true },
    }) as Promise<{ params: unknown; enabled: boolean } | null>;
  }

  private _normalizedHash(body: string): string {
    const normalized = body.trim().toLowerCase().replace(/\s+/g, ' ');
    return crypto.createHash('sha256').update(normalized).digest('hex');
  }
}
