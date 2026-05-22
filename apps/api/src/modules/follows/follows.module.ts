import { Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { AccessControlModule } from '../../shared/access-control.module';
import { FollowService } from './follow.service';
import { FollowController } from './follow.controller';
import { FollowRecommendationService } from './follow-recommendation.service';
import { FollowRecommendationController } from './follow-recommendation.controller';
import { FollowRecommendationCron } from './follow-recommendation.cron';

@Module({
  imports: [PrismaModule, AccessControlModule],
  controllers: [FollowController, FollowRecommendationController],
  providers: [
    FollowService,
    FollowRecommendationService,
    FollowRecommendationCron,
  ],
  exports: [FollowService, FollowRecommendationService],
})
export class FollowsModule {}
