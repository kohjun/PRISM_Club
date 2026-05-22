import { Module } from '@nestjs/common';
import { CommunityModule } from '../community/community.module';
import { PostService } from './post.service';
import { ReplyService } from './reply.service';
import { ReactionService } from './reaction.service';
import { PostController } from './post.controller';
import { ReplyController } from './reply.controller';
import { ReactionController } from './reaction.controller';
import { RecruitmentService } from './recruitment.service';
import { RecruitmentController } from './recruitment.controller';

@Module({
  imports: [CommunityModule],
  controllers: [
    PostController,
    ReplyController,
    ReactionController,
    RecruitmentController,
  ],
  providers: [
    PostService,
    ReplyService,
    ReactionService,
    RecruitmentService,
  ],
  exports: [PostService, ReplyService, ReactionService, RecruitmentService],
})
export class PostsModule {}
