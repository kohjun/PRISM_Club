import { Module } from '@nestjs/common';
import { CommunityModule } from '../community/community.module';
import { PostService } from './post.service';
import { ReplyService } from './reply.service';
import { ReactionService } from './reaction.service';
import { PostController } from './post.controller';
import { ReplyController } from './reply.controller';
import { ReactionController } from './reaction.controller';

@Module({
  imports: [CommunityModule],
  controllers: [PostController, ReplyController, ReactionController],
  providers: [PostService, ReplyService, ReactionService],
  exports: [PostService, ReplyService, ReactionService],
})
export class PostsModule {}
