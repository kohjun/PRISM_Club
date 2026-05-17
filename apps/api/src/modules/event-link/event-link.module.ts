import { Logger, Module } from '@nestjs/common';
import { CommunityModule } from '../community/community.module';
import { EventCardController } from './event-card.controller';
import { EventCardService } from './event-card.service';
import { EventsClientAdminController } from './events-client-admin.controller';
import { MockEventsClient } from './clients/mock-events.client';
import { PrismEventsClient } from './clients/prism-events.client';
import { EVENTS_CLIENT } from './clients/events-client.interface';

const moduleLog = new Logger('EventLinkModule');

function selectClient(): typeof MockEventsClient | typeof PrismEventsClient {
  const mode = (process.env.EVENTS_CLIENT_MODE ?? 'mock').toLowerCase();
  if (mode === 'prism') {
    if (!process.env.PRISM_EVENTS_API_BASE_URL) {
      moduleLog.warn(
        'EVENTS_CLIENT_MODE=prism but PRISM_EVENTS_API_BASE_URL not set; falling back to MockEventsClient',
      );
      return MockEventsClient;
    }
    moduleLog.log('Using PrismEventsClient');
    return PrismEventsClient;
  }
  return MockEventsClient;
}

@Module({
  imports: [CommunityModule],
  controllers: [EventCardController, EventsClientAdminController],
  providers: [
    EventCardService,
    MockEventsClient,
    PrismEventsClient,
    { provide: EVENTS_CLIENT, useClass: selectClient() },
  ],
  exports: [EventCardService],
})
export class EventLinkModule {}
