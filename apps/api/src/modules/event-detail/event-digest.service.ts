import {
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import {
  EventDigestDTO,
  EventDigestPayloadV1,
} from './dto/event-digest.dto';

const RECAP_WINDOW_HOURS = 7 * 24; // a week of activity after start

/**
 * Post-event recap digest (P3.5). One row per completed event,
 * generated automatically by the P3.2 cron at D+1 OR on demand via
 * an ops endpoint. Pattern mirrors TopicHubDigest:
 *   - period_start = event.startsAt (rounded to the hour)
 *   - period_end   = period_start + 7d (covers the post-event "buzz")
 *   - upsert on (eventCardId, periodStart) so re-runs are idempotent
 *   - empty events (no posts AND no reviews) skip persistence
 */
@Injectable()
export class EventDigestService {
  private readonly log = new Logger(EventDigestService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ---- Read --------------------------------------------------------

  async getForEvent(eventCardId: string): Promise<EventDigestDTO | null> {
    const event = await this.prisma.eventCard.findUnique({
      where: { id: eventCardId },
      select: { id: true },
    });
    if (!event) {
      throw new NotFoundException(`Event not found: ${eventCardId}`);
    }
    const row = await this.prisma.eventCardDigest.findFirst({
      where: { eventCardId },
      orderBy: { periodEnd: 'desc' },
    });
    if (!row) return null;
    return this.toDTO(row);
  }

  // ---- Write -------------------------------------------------------

  async generateForEvent(
    eventCardId: string,
  ): Promise<{ wrote: boolean; reason?: string }> {
    const event = await this.prisma.eventCard.findUnique({
      where: { id: eventCardId },
      include: {
        topicHubLinks: {
          include: {
            hub: { include: { category: { include: { space: true } } } },
          },
        },
      },
    });
    if (!event) {
      throw new NotFoundException(`Event not found: ${eventCardId}`);
    }
    // First linked hub's accessPolicy, defaulting to PUBLIC. EventCard
    // itself is global; this just propagates the access policy into the
    // notification payload for the future digest fan-out.
    const spaceAccessPolicy =
      event.topicHubLinks[0]?.hub?.category?.space?.accessPolicy ?? 'PUBLIC';

    const periodStart = roundDownToHour(event.startsAt);
    const periodEnd = new Date(
      periodStart.getTime() + RECAP_WINDOW_HOURS * 60 * 60 * 1000,
    );

    // Top posts attached to this event in the recap window.
    const topPosts = await this.prisma.post.findMany({
      where: {
        status: 'VISIBLE',
        attachments: {
          some: { attachmentType: 'EVENT_CARD', targetId: eventCardId },
        },
        createdAt: { gte: periodStart, lt: periodEnd },
      },
      include: { room: true },
      orderBy: [
        { likeCount: 'desc' },
        { bookmarkCount: 'desc' },
        { replyCount: 'desc' },
        { createdAt: 'desc' },
      ],
      take: 5,
    });

    // Top reviews (highest rating first, then most recent).
    const topReviews = await this.prisma.eventReview.findMany({
      where: { eventCardId, status: 'VISIBLE' },
      orderBy: [{ rating: 'desc' }, { createdAt: 'desc' }],
      take: 5,
      include: { user: { include: { profile: true } } },
    });

    const reviewAgg = await this.prisma.eventReview.aggregate({
      where: { eventCardId, status: 'VISIBLE' },
      _avg: { rating: true },
      _count: { _all: true },
    });

    if (topPosts.length === 0 && topReviews.length === 0) {
      return { wrote: false, reason: 'empty-event' };
    }

    const payload: EventDigestPayloadV1 = {
      schemaVersion: 1,
      spaceAccessPolicy,
      topPosts: topPosts.map((p) => ({
        id: p.id,
        snippet: p.body.length > 120 ? `${p.body.slice(0, 120)}…` : p.body,
        room_slug: p.room.slug,
        like_count: p.likeCount,
        reply_count: p.replyCount,
      })),
      topReviews: topReviews.map((r) => ({
        id: r.id,
        rating: r.rating,
        snippet: r.body.length > 120 ? `${r.body.slice(0, 120)}…` : r.body,
        user_nickname: r.user?.profile?.nickname ?? null,
        created_at: r.createdAt.toISOString(),
      })),
      reviewCount: reviewAgg._count._all ?? 0,
      averageRating: reviewAgg._avg.rating ?? null,
    };

    await this.prisma.eventCardDigest.upsert({
      where: {
        eventCardId_periodStart: { eventCardId, periodStart },
      },
      create: {
        eventCardId,
        periodStart,
        periodEnd,
        payload: payload as unknown as object,
      },
      update: {
        periodEnd,
        payload: payload as unknown as object,
        generatedAt: new Date(),
      },
    });
    return { wrote: true };
  }

  /**
   * Iterate every event whose startsAt+24h is in the [now-1h, now+1h]
   * window. Called from the P3.2 cron hourly tick so D+1 recaps
   * publish automatically.
   */
  async generateDueRecaps(now: Date): Promise<{ scanned: number; written: number }> {
    const dueStart = new Date(now.getTime() - 24 * 60 * 60 * 1000 - 60 * 60 * 1000);
    const dueEnd = new Date(now.getTime() - 24 * 60 * 60 * 1000 + 60 * 60 * 1000);
    const events = await this.prisma.eventCard.findMany({
      where: {
        startsAt: { gte: dueStart, lte: dueEnd },
      },
      take: 100,
      select: { id: true },
    });
    let written = 0;
    for (const e of events) {
      try {
        const r = await this.generateForEvent(e.id);
        if (r.wrote) written += 1;
      } catch (err) {
        this.log.warn(
          `event recap generation failed for ${e.id}: ${err instanceof Error ? err.message : String(err)}`,
        );
      }
    }
    return { scanned: events.length, written };
  }

  private toDTO(row: {
    eventCardId: string;
    periodStart: Date;
    periodEnd: Date;
    generatedAt: Date;
    payload: unknown;
  }): EventDigestDTO {
    return {
      event_card_id: row.eventCardId,
      period_start: row.periodStart.toISOString(),
      period_end: row.periodEnd.toISOString(),
      generated_at: row.generatedAt.toISOString(),
      payload: row.payload as EventDigestPayloadV1,
    };
  }
}

function roundDownToHour(d: Date): Date {
  return new Date(
    Date.UTC(
      d.getUTCFullYear(),
      d.getUTCMonth(),
      d.getUTCDate(),
      d.getUTCHours(),
      0,
      0,
      0,
    ),
  );
}
