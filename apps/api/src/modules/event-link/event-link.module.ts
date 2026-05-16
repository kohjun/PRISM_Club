import { Module } from '@nestjs/common';
import { CommunityModule } from '../community/community.module';
import { EventCardController } from './event-card.controller';
import { EventCardService } from './event-card.service';
import { MockEventsClient } from './clients/mock-events.client';
import { EVENTS_CLIENT } from './clients/events-client.interface';

@Module({
  imports: [CommunityModule],
  controllers: [EventCardController],
  providers: [
    EventCardService,
    // Swap to a real HttpEventsClient binding in phase 2.
    { provide: EVENTS_CLIENT, useClass: MockEventsClient },
  ],
  exports: [EventCardService],
})
export class EventLinkModule {}
