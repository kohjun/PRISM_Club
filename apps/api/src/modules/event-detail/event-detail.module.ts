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

@Module({
  imports: [CommunityModule, PostsModule],
  controllers: [
    EventDetailController,
    EventRsvpController,
    EventReminderOpsController,
  ],
  providers: [
    EventDetailService,
    EventRsvpService,
    EventIcsService,
    EventReminderCron,
  ],
  exports: [
    EventDetailService,
    EventRsvpService,
    EventIcsService,
    EventReminderCron,
  ],
})
export class EventDetailModule {}
