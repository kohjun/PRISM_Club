import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../../shared/prisma.service';
import { CronLockService, CRON_LOCK_IDS } from '../../shared/cron-lock.service';

const DEFAULT_RETENTION_DAYS = 180;
const BATCH_SIZE = 10_000;

/**
 * P5.5 analytics retention.
 *
 * Daily prune of `analytics_events` rows older than
 * ANALYTICS_RETENTION_DAYS (default 180). Runs at 04:00 KST under an
 * advisory lock so multi-replica deployments don't race on the same
 * DELETE batch. ANALYTICS_RETENTION_DRY_RUN=1 flips it into log-only
 * mode for the first staging cycle.
 */
@Injectable()
export class AnalyticsRetentionCron {
  private readonly log = new Logger(AnalyticsRetentionCron.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cronLock: CronLockService,
  ) {}

  @Cron('0 0 19 * * *') // 04:00 KST = 19:00 UTC previous day
  async dailyTick(): Promise<void> {
    if (process.env.ANALYTICS_RETENTION_CRON_ENABLED === '0') return;
    const got = await this.cronLock.tryLock(CRON_LOCK_IDS.ANALYTICS_RETENTION);
    if (!got) return;
    try {
      await this.run();
    } catch (e) {
      this.log.warn(
        `retention tick failed: ${e instanceof Error ? e.message : String(e)}`,
      );
    } finally {
      await this.cronLock.unlock(CRON_LOCK_IDS.ANALYTICS_RETENTION);
    }
  }

  async run(): Promise<{ scanned_to: string; deleted: number; dry_run: boolean }> {
    const days = this._retentionDays();
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    const dryRun = process.env.ANALYTICS_RETENTION_DRY_RUN === '1';

    if (dryRun) {
      const count = await this.prisma.analyticsEvent.count({
        where: { createdAt: { lt: cutoff } },
      });
      this.log.log(
        `analytics retention DRY_RUN: would delete ${count} rows older than ${cutoff.toISOString()}`,
      );
      return {
        scanned_to: cutoff.toISOString(),
        deleted: count,
        dry_run: true,
      };
    }

    // Batched delete to keep transaction sizes bounded.
    let total = 0;
    for (;;) {
      const idRows = await this.prisma.analyticsEvent.findMany({
        where: { createdAt: { lt: cutoff } },
        select: { id: true },
        take: BATCH_SIZE,
      });
      if (idRows.length === 0) break;
      const res = await this.prisma.analyticsEvent.deleteMany({
        where: { id: { in: idRows.map((r) => r.id) } },
      });
      total += res.count;
      if (idRows.length < BATCH_SIZE) break;
    }
    return {
      scanned_to: cutoff.toISOString(),
      deleted: total,
      dry_run: false,
    };
  }

  private _retentionDays(): number {
    const raw = parseInt(process.env.ANALYTICS_RETENTION_DAYS ?? '', 10);
    return Number.isFinite(raw) && raw > 0 ? raw : DEFAULT_RETENTION_DAYS;
  }

}
