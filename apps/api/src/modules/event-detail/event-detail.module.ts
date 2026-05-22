import { Module } from '@nestjs/common';
import { CommunityModule } from '../community/community.module';
import { PostsModule } from '../posts/posts.module';
import { EventDetailController } from './event-detail.controller';
import { EventDetailService } from './event-detail.service';
import { EventRsvpService } from './event-rsvp.service';
import { EventRsvpController } from './event-rsvp.controller';

@Module({
  imports: [CommunityModule, PostsModule],
  controllers: [EventDetailController, EventRsvpController],
  providers: [EventDetailService, EventRsvpService],
  exports: [EventDetailService, EventRsvpService],
})
export class EventDetailModule {}
