import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { TopicHubSimilarityService } from './topic-hub-similarity.service';

@Injectable()
export class TopicHubSimilarityCron {
  private readonly log = new Logger(TopicHubSimilarityCron.name);

  constructor(private readonly svc: TopicHubSimilarityService) {}

  /**
   * 03:30 KST = 18:30 UTC previous day. Advisory lock 854_305 lives in
   * the service. Offset from `FollowRecommendationCron` (03:00 KST) by
   * 30 minutes so the two Jaccard sweeps don't compete for DB CPU on a
   * single-worker host. Gated by the same `RECOMMENDATIONS_CRON_ENABLED`
   * env flag as P4.3 so an operator can disable both with one flip.
   */
  @Cron('0 30 18 * * *')
  async daily(): Promise<void> {
    if (process.env.RECOMMENDATIONS_CRON_ENABLED === '0') return;
    try {
      const result = await this.svc.recomputeAll();
      this.log.log(
        `topic-hub similarity: scanned=${result.hubs_scanned} written=${result.rows_written}`,
      );
    } catch (e) {
      this.log.warn(
        `topic-hub similarity failed: ${e instanceof Error ? e.message : String(e)}`,
      );
    }
  }
}
