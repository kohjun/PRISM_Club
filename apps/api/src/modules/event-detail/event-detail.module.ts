import { Module } from '@nestjs/common';
import { CommunityModule } from '../community/community.module';
import { PostsModule } from '../posts/posts.module';
import { EventDetailController } from './event-detail.controller';
import { EventDetailService } from './event-detail.service';
import { EventRsvpService } from './event-rsvp.service';
import { EventRsvpController } from './event-rsvp.controller';
import { EventIcsService } from './event-ics.service';
import { EventReminderCron } from './event-reminder.cron';
import { EventReminderOpsController } from './event-reminder-ops.controller';
import { EventReviewService } from './event-review.service';
import { EventReviewController } from './event-review.controller';
import { EventDigestService } from './event-digest.service';
import { EventLiveService } from './event-live.service';
import { EventLiveController } from './event-live.controller';

@Module({
  imports: [CommunityModule, PostsModule],
  controllers: [
    EventDetailController,
    EventRsvpController,
    EventReminderOpsController,
    EventReviewController,
    EventLiveController,
  ],
  providers: [
    EventDetailService,
    EventRsvpService,
    EventIcsService,
    EventReminderCron,
    EventReviewService,
    EventDigestService,
    EventLiveService,
  ],
  exports: [
    EventDetailService,
    EventRsvpService,
    EventIcsService,
    EventReminderCron,
    EventReviewService,
    EventDigestService,
    EventLiveService,
  ],
})
export class EventDetailModule {}
