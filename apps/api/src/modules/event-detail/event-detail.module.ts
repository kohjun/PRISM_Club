import { Module } from '@nestjs/common';
import { CommunityModule } from '../community/community.module';
import { PostsModule } from '../posts/posts.module';
import { EventDetailController } from './event-detail.controller';
import { EventDetailService } from './event-detail.service';

@Module({
  imports: [CommunityModule, PostsModule],
  controllers: [EventDetailController],
  providers: [EventDetailService],
  exports: [EventDetailService],
})
export class EventDetailModule {}
