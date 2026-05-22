import { Inject, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { EVENTS_CLIENT, ExternalEvent, IEventsClient } from './clients/events-client.interface';
import { RoomService } from '../community/room.service';

const RECENT_UPDATE_NOTIFY_WINDOW_SEC_DEFAULT = 86_400; // 24h

@Injectable()
export class EventCardService {
  private readonly log = new Logger(EventCardService.name);

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
   *
   * P3.1: when the upstream changes startsAt, venueName, or eventStatus
   * we fan out an EVENT_UPDATED notification to every user with an
   * INTERESTED/GOING/ATTENDED RSVP for this event. The notification is
   * de-duplicated against analytics_events so the same (event, user)
   * pair doesn't get spammed if upstream flutters multiple times within
   * RECENT_EVENT_UPDATE_NOTIFY_WINDOW_SEC.
   */
  async upsertFromExternal(externalEventId: string) {
    const external = await this.eventsClient.getById(externalEventId);
    if (!external) {
      throw new NotFoundException(`External event not found: ${externalEventId}`);
    }

    const before = await this.prisma.eventCard.findUnique({
      where: { externalEventId: external.external_event_id },
    });

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

    if (before && this._hasMaterialChange(before, card)) {
      // Non-blocking: notification fan-out failures should never roll
      // back the upstream sync.
      void this._fanoutEventUpdated(card, before).catch((e) => {
        this.log.warn(
          `EVENT_UPDATED fan-out failed for card=${card.id}: ${e instanceof Error ? e.message : String(e)}`,
        );
      });
    }

    return this.rooms.toEventCardDTO(card);
  }

  private _hasMaterialChange(
    before: {
      title: string;
      venueName: string;
      startsAt: Date;
      eventStatus: string;
    },
    after: {
      title: string;
      venueName: string;
      startsAt: Date;
      eventStatus: string;
    },
  ): boolean {
    return (
      before.title !== after.title ||
      before.venueName !== after.venueName ||
      before.startsAt.getTime() !== after.startsAt.getTime() ||
      before.eventStatus !== after.eventStatus
    );
  }

  private async _fanoutEventUpdated(
    after: {
      id: string;
      title: string;
      venueName: string;
      region: string;
      startsAt: Date;
      eventStatus: string;
    },
    before: {
      title: string;
      venueName: string;
      startsAt: Date;
      eventStatus: string;
    },
  ): Promise<void> {
    const windowSec = this._dedupWindowSec();
    const recipients = await this.prisma.eventRsvp.findMany({
      where: {
        eventCardId: after.id,
        status: { in: ['INTERESTED', 'GOING'] },
      },
      select: { userId: true },
    });
    if (recipients.length === 0) return;

    // Drop recipients that already received an EVENT_UPDATED for this
    // card within the dedup window.
    const cutoff = new Date(Date.now() - windowSec * 1000);
    const recentRows = await this.prisma.analyticsEvent.findMany({
      where: {
        eventType: 'EVENT_UPDATED_NOTIFY',
        createdAt: { gte: cutoff },
        payload: { path: ['event_card_id'], equals: after.id },
      },
      select: { actorId: true },
    });
    const recentRecipients = new Set(
      recentRows.map((r) => r.actorId).filter((x): x is string => Boolean(x)),
    );

    const payloadBase = {
      eventCardId: after.id,
      title: after.title,
      region: after.region,
      startsAtBefore: before.startsAt.toISOString(),
      startsAtAfter: after.startsAt.toISOString(),
      venueNameChanged: before.venueName !== after.venueName,
      statusBefore: before.eventStatus,
      statusAfter: after.eventStatus,
      spaceAccessPolicy: 'PUBLIC',
    };

    for (const r of recipients) {
      if (recentRecipients.has(r.userId)) continue;
      await this.prisma.notification.create({
        data: {
          userId: r.userId,
          type: 'EVENT_UPDATED',
          payload: payloadBase,
        },
      });
      await this.prisma.analyticsEvent.create({
        data: {
          actorId: r.userId,
          eventType: 'EVENT_UPDATED_NOTIFY',
          payload: { event_card_id: after.id },
        },
      });
    }
  }

  private _dedupWindowSec(): number {
    const raw = parseInt(
      process.env.RECENT_EVENT_UPDATE_NOTIFY_WINDOW_SEC ?? '',
      10,
    );
    return Number.isFinite(raw) && raw > 0
      ? raw
      : RECENT_UPDATE_NOTIFY_WINDOW_SEC_DEFAULT;
  }
}
