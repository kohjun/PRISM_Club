import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { WeeklyDigestService } from './weekly-digest.service';

@Injectable()
export class WeeklyDigestCron {
  private readonly log = new Logger(WeeklyDigestCron.name);

  constructor(private readonly svc: WeeklyDigestService) {}

  /**
   * Sunday 18:00 KST = Sunday 09:00 UTC. Batches one BATCH_SIZE-sized
   * slice; the next tick (a full week later) picks up the rest.
   * Production should re-run hourly during the rollout window to
   * drain the queue inside the same day.
   */
  @Cron('0 0 9 * * 0')
  async sunday(): Promise<void> {
    if (process.env.WEEKLY_DIGEST_CRON_ENABLED === '0') return;
    try {
      const result = await this.svc.run();
      this.log.log(
        `weekly digest: candidates=${result.candidates} sent=${result.sent} skipped_empty=${result.skipped_empty} skipped_cooldown=${result.skipped_cooldown}`,
      );
    } catch (e) {
      this.log.warn(
        `weekly digest failed: ${e instanceof Error ? e.message : String(e)}`,
      );
    }
  }
}
