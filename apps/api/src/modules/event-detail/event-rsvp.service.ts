import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AnalyticsService } from '../analytics/analytics.service';
import {
  MyRsvpEntryDTO,
  MyRsvpsListDTO,
  RsvpDTO,
  RsvpStateDTO,
  RsvpStatus,
} from './dto/rsvp.dto';

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;
const VALID_STATUS = new Set<RsvpStatus>(['INTERESTED', 'GOING', 'ATTENDED']);

/**
 * EventRsvp service (P3.1).
 *
 * The `(event_card_id, user_id)` unique constraint makes RSVP toggles
 * idempotent: the same user posting twice gets a single row whose
 * status is the latest value. DELETE removes the row outright so users
 * can drop out without leaving a stale INTERESTED record.
 *
 * The fan-out trigger for EVENT_UPDATED notifications is wired in
 * event-card.service `upsertFromExternal` (sibling change in this PR)
 * so it stays adjacent to the source-of-truth update.
 */
@Injectable()
export class EventRsvpService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly analytics: AnalyticsService,
  ) {}

  async setRsvp(
    eventCardId: string,
    userId: string,
    status: string,
  ): Promise<RsvpDTO> {
    if (!VALID_STATUS.has(status as RsvpStatus)) {
      throw new BadRequestException(
        `status must be one of ${[...VALID_STATUS].join(', ')}`,
      );
    }
    const event = await this.prisma.eventCard.findUnique({
      where: { id: eventCardId },
    });
    if (!event) {
      throw new NotFoundException(`Event not found: ${eventCardId}`);
    }
    // ATTENDED is only valid after the event has started OR was already
    // marked COMPLETED by the sync side. Prevents "I attended" claims on
    // future events.
    if (
      status === 'ATTENDED' &&
      event.eventStatus !== 'COMPLETED' &&
      event.startsAt.getTime() > Date.now()
    ) {
      throw new ForbiddenException(
        'ATTENDED can only be set after the event has started',
      );
    }

    const row = await this.prisma.eventRsvp.upsert({
      where: { eventCardId_userId: { eventCardId, userId } },
      create: { eventCardId, userId, status },
      update: { status },
    });
    this.analytics.record({
      actorId: userId,
      eventType: 'EVENT_RSVP_CHANGED',
      payload: { event_card_id: eventCardId, status },
    });
    return this.toDTO(row);
  }

  async removeRsvp(
    eventCardId: string,
    userId: string,
  ): Promise<{ ok: boolean }> {
    const deleted = await this.prisma.eventRsvp.deleteMany({
      where: { eventCardId, userId },
    });
    if (deleted.count > 0) {
      this.analytics.record({
        actorId: userId,
        eventType: 'EVENT_RSVP_CHANGED',
        payload: { event_card_id: eventCardId, status: 'REMOVED' },
      });
    }
    return { ok: true };
  }

  async getState(
    eventCardId: string,
    userId: string,
  ): Promise<RsvpStateDTO> {
    const event = await this.prisma.eventCard.findUnique({
      where: { id: eventCardId },
      select: { id: true },
    });
    if (!event) {
      throw new NotFoundException(`Event not found: ${eventCardId}`);
    }
    const [mine, counts] = await Promise.all([
      this.prisma.eventRsvp.findUnique({
        where: { eventCardId_userId: { eventCardId, userId } },
      }),
      this.prisma.eventRsvp.groupBy({
        by: ['status'],
        where: { eventCardId },
        _count: { status: true },
      }),
    ]);
    const buckets = { interested: 0, going: 0, attended: 0 };
    for (const c of counts) {
      if (c.status === 'INTERESTED') buckets.interested = c._count.status;
      if (c.status === 'GOING') buckets.going = c._count.status;
      if (c.status === 'ATTENDED') buckets.attended = c._count.status;
    }
    return {
      my_status: (mine?.status as RsvpStatus | undefined) ?? null,
      counts: buckets,
    };
  }

  async listMine(
    userId: string,
    opts: { status?: string; cursor?: string; limit?: number } = {},
  ): Promise<MyRsvpsListDTO> {
    const limit = Math.max(1, Math.min(opts.limit ?? DEFAULT_LIMIT, MAX_LIMIT));
    const status = opts.status && VALID_STATUS.has(opts.status as RsvpStatus)
      ? opts.status
      : undefined;

    const rows = await this.prisma.eventRsvp.findMany({
      where: { userId, ...(status ? { status } : {}) },
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(opts.cursor
        ? { cursor: { id: opts.cursor }, skip: 1 }
        : {}),
      include: { eventCard: true },
    });
    const hasMore = rows.length > limit;
    const sliced = hasMore ? rows.slice(0, limit) : rows;
    const items: MyRsvpEntryDTO[] = sliced.map((r) => ({
      rsvp: this.toDTO(r),
      event_card: {
        id: r.eventCard.id,
        title: r.eventCard.title,
        venue_name: r.eventCard.venueName,
        region: r.eventCard.region,
        starts_at: r.eventCard.startsAt.toISOString(),
        event_status: r.eventCard.eventStatus,
        thumbnail_url: r.eventCard.thumbnailUrl,
      },
    }));
    return {
      items,
      next_cursor: hasMore ? sliced[sliced.length - 1].id : null,
    };
  }

  private toDTO(row: {
    id: string;
    eventCardId: string;
    userId: string;
    status: string;
    createdAt: Date;
    updatedAt: Date;
  }): RsvpDTO {
    return {
      id: row.id,
      event_card_id: row.eventCardId,
      user_id: row.userId,
      status: row.status as RsvpStatus,
      created_at: row.createdAt.toISOString(),
      updated_at: row.updatedAt.toISOString(),
    };
  }
}
