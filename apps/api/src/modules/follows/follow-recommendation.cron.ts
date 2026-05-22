import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { FollowRecommendationService } from './follow-recommendation.service';

@Injectable()
export class FollowRecommendationCron {
  private readonly log = new Logger(FollowRecommendationCron.name);

  constructor(private readonly svc: FollowRecommendationService) {}

  /** 03:00 KST = 18:00 UTC previous day. Advisory lock lives in the service. */
  @Cron('0 0 18 * * *')
  async daily(): Promise<void> {
    if (process.env.RECOMMENDATIONS_CRON_ENABLED === '0') return;
    try {
      const result = await this.svc.recomputeAll();
      this.log.log(
        `follow recs: scanned=${result.users_scanned} written=${result.rows_written}`,
      );
    } catch (e) {
      this.log.warn(
        `follow recs failed: ${e instanceof Error ? e.message : String(e)}`,
      );
    }
  }
}
