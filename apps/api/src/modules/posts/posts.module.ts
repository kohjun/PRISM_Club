import { Module } from '@nestjs/common';
import { CommunityModule } from '../community/community.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PostService } from './post.service';
import { ReplyService } from './reply.service';
import { ReactionService } from './reaction.service';
import { PollService } from './poll.service';
import { BoostService } from './boost.service';
import { PostController } from './post.controller';
import { ReplyController } from './reply.controller';
import { ReactionController } from './reaction.controller';
import { PollController } from './poll.controller';
import { BoostController } from './boost.controller';
import { RecruitmentService } from './recruitment.service';
import { RecruitmentController } from './recruitment.controller';

@Module({
  imports: [CommunityModule, NotificationsModule],
  controllers: [
    PostController,
    ReplyController,
    ReactionController,
    PollController,
    BoostController,
    RecruitmentController,
  ],
  providers: [
    PostService,
    ReplyService,
    ReactionService,
    PollService,
    BoostService,
    RecruitmentService,
  ],
  exports: [
    PostService,
    ReplyService,
    ReactionService,
    PollService,
    BoostService,
    RecruitmentService,
  ],
})
export class PostsModule {}
