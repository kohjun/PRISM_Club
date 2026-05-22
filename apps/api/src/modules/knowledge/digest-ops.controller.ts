import { Controller, HttpCode, Post, Query } from '@nestjs/common';
import { Roles } from '../../shared/decorators/roles.decorator';
import { DigestService } from './digest.service';

@Controller()
export class DigestOpsController {
  constructor(private readonly digest: DigestService) {}

  /**
   * Manual digest refresh. Returns a summary of how many hubs were
   * processed and how many got a row (vs. skipped because the week
   * was empty). Run by a curator click today; the future weekly cron
   * (P3.2 infra, Mon 09:00 KST) will call the same service method.
   */
  @Roles('CURATOR', 'MODERATOR', 'ADMIN')
  @Post('ops/digests/refresh')
  @HttpCode(200)
  refresh(@Query('period') periodRaw?: string) {
    const period = periodRaw === 'previous' ? 'previous' : 'current';
    return this.digest.refreshAll(period);
  }
}
