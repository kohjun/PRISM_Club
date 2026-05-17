import { Controller, Get } from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { AnalyticsService } from './analytics.service';

/**
 * Admin-only diagnostic endpoint. Returns 30-day rollup counts grouped by
 * event_type. There is no public read endpoint — analytics are emitted
 * fire-and-forget on the write path; summaries are for ops only.
 */
@Controller('admin/analytics')
export class AnalyticsController {
  constructor(private readonly svc: AnalyticsService) {}

  @Get('summary')
  summary(@CurrentUser() user: RequestUser) {
    return this.svc.summarize(user);
  }
}
