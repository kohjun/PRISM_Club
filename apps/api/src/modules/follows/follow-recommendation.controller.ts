import {
  Controller,
  Get,
  HttpCode,
  Post,
  Query,
} from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { Roles } from '../../shared/decorators/roles.decorator';
import { FollowRecommendationService } from './follow-recommendation.service';

@Controller()
export class FollowRecommendationController {
  constructor(private readonly svc: FollowRecommendationService) {}

  @Get('me/recommendations/users')
  forMe(
    @CurrentUser() user: RequestUser,
    @Query('limit') limit?: string,
  ) {
    return this.svc.listForUser(user, limit ? parseInt(limit, 10) : 10);
  }

  /** Manual catch-up after a deploy hop or rule change. */
  @Roles('ADMIN', 'CURATOR')
  @Post('admin/recommendations/recompute')
  @HttpCode(200)
  recompute() {
    return this.svc.recomputeAll();
  }
}
