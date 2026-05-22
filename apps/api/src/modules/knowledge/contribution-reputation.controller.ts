import { Controller, Get, Param, Query } from '@nestjs/common';
import { Roles } from '../../shared/decorators/roles.decorator';
import { ContributionReputationService } from './contribution-reputation.service';

@Controller()
export class ContributionReputationController {
  constructor(private readonly svc: ContributionReputationService) {}

  /** Public read — profiles already surface other public-facing stats. */
  @Get('users/:userId/reputation')
  forUser(@Param('userId') userId: string) {
    return this.svc.getForUserStrict(userId);
  }

  /** Curator/admin leaderboard, ordered by weighted_score desc. */
  @Roles('CURATOR', 'MODERATOR', 'ADMIN')
  @Get('admin/contribution-reputation')
  leaderboard(@Query('limit') limit?: string) {
    return this.svc.leaderboard(limit ? parseInt(limit, 10) : undefined);
  }
}
