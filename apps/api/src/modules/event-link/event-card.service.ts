import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { EVENTS_CLIENT, ExternalEvent, IEventsClient } from './clients/events-client.interface';
import { RoomService } from '../community/room.service';

@Injectable()
export class EventCardService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(EVENTS_CLIENT) private readonly eventsClient: IEventsClient,
    private readonly rooms: RoomService,
  ) {}

  async search(q: string, status?: 'UPCOMING' | 'COMPLETED'): Promise<ExternalEvent[]> {
    return this.eventsClient.search(q, status ? { status } : undefined);
  }

  /**
   * Upsert an EventCard for a given external event. Re-runs idempotently:
   * matches on `external_event_id` UNIQUE. On second call, refreshes
   * `synced_at` and any drifted metadata.
   */
  async upsertFromExternal(externalEventId: string) {
    const external = await this.eventsClient.getById(externalEventId);
    if (!external) {
      throw new NotFoundException(`External event not found: ${externalEventId}`);
    }

    const card = await this.prisma.eventCard.upsert({
      where: { externalEventId: external.external_event_id },
      create: {
        externalEventId: external.external_event_id,
        title: external.title,
        venueName: external.venue_name,
        region: external.region,
        startsAt: new Date(external.starts_at),
        eventStatus: external.event_status,
        thumbnailUrl: external.thumbnail_url,
      },
      update: {
        title: external.title,
        venueName: external.venue_name,
        region: external.region,
        startsAt: new Date(external.starts_at),
        eventStatus: external.event_status,
        thumbnailUrl: external.thumbnail_url,
        syncedAt: new Date(),
      },
    });

    return this.rooms.toEventCardDTO(card);
  }
}
