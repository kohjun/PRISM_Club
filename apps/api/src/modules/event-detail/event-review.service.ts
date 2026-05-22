import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AnalyticsService } from '../analytics/analytics.service';
import {
  EventReviewDTO,
  EventReviewsListDTO,
} from './dto/review.dto';

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;
const MAX_BODY_LEN = 2000;

interface CreateReviewInput {
  rating: number;
  body: string;
}

interface PatchReviewInput {
  rating?: number;
  body?: string;
}

/**
 * P3.3 event reviews — `(event_card, user)` unique so a single
 * attendee revises their existing review rather than duplicating it.
 *
 * Write gates:
 *   - event.eventStatus must be COMPLETED.
 *   - the caller must have an ATTENDED RSVP for the event.
 *
 * Visibility:
 *   - returns only `status='VISIBLE'` rows to non-author callers;
 *   - the author always sees their own row regardless of status so a
 *     post-hide message lands somewhere useful.
 */
@Injectable()
export class EventReviewService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly analytics: AnalyticsService,
  ) {}

  async createOrUpdate(
    eventCardId: string,
    userId: string,
    input: CreateReviewInput,
  ): Promise<EventReviewDTO> {
    this._assertRating(input.rating);
    const body = (input.body ?? '').trim();
    if (body.length === 0) {
      throw new BadRequestException('body is required');
    }
    if (body.length > MAX_BODY_LEN) {
      throw new BadRequestException(`body must be <= ${MAX_BODY_LEN} chars`);
    }

    const event = await this.prisma.eventCard.findUnique({
      where: { id: eventCardId },
    });
    if (!event) {
      throw new NotFoundException(`Event not found: ${eventCardId}`);
    }
    if (event.eventStatus !== 'COMPLETED') {
      throw new ConflictException('Event has not completed yet');
    }
    const rsvp = await this.prisma.eventRsvp.findUnique({
      where: { eventCardId_userId: { eventCardId, userId } },
    });
    if (!rsvp || rsvp.status !== 'ATTENDED') {
      throw new ForbiddenException(
        'Only ATTENDED RSVPs can post a review for this event',
      );
    }

    const row = await this.prisma.eventReview.upsert({
      where: { eventCardId_userId: { eventCardId, userId } },
      create: {
        eventCardId,
        userId,
        rating: input.rating,
        body: body.slice(0, MAX_BODY_LEN),
      },
      update: {
        rating: input.rating,
        body: body.slice(0, MAX_BODY_LEN),
      },
      include: { user: { include: { profile: true } } },
    });
    this.analytics.record({
      actorId: userId,
      eventType: 'EVENT_REVIEW_CREATED',
      payload: { event_card_id: eventCardId, rating: input.rating },
    });
    return this.toDTO(row);
  }

  async patch(
    reviewId: string,
    userId: string,
    input: PatchReviewInput,
  ): Promise<EventReviewDTO> {
    const existing = await this.prisma.eventReview.findUnique({
      where: { id: reviewId },
    });
    if (!existing) {
      throw new NotFoundException(`Review not found: ${reviewId}`);
    }
    if (existing.userId !== userId) {
      throw new ForbiddenException('Only the author can edit this review');
    }
    if (existing.status !== 'VISIBLE') {
      throw new ConflictException(
        `Cannot edit a ${existing.status.toLowerCase()} review`,
      );
    }
    const data: { rating?: number; body?: string } = {};
    if (input.rating !== undefined) {
      this._assertRating(input.rating);
      data.rating = input.rating;
    }
    if (input.body !== undefined) {
      const body = input.body.trim();
      if (body.length === 0 || body.length > MAX_BODY_LEN) {
        throw new BadRequestException('body length out of range');
      }
      data.body = body;
    }
    const row = await this.prisma.eventReview.update({
      where: { id: reviewId },
      data,
      include: { user: { include: { profile: true } } },
    });
    return this.toDTO(row);
  }

  async deleteByAuthor(reviewId: string, userId: string): Promise<{ ok: boolean }> {
    const existing = await this.prisma.eventReview.findUnique({
      where: { id: reviewId },
    });
    if (!existing) return { ok: true };
    if (existing.userId !== userId) {
      throw new ForbiddenException('Only the author can delete this review');
    }
    await this.prisma.eventReview.update({
      where: { id: reviewId },
      data: { status: 'DELETED' },
    });
    return { ok: true };
  }

  async listForEvent(
    eventCardId: string,
    viewerId: string,
    opts: { cursor?: string; limit?: number } = {},
  ): Promise<EventReviewsListDTO> {
    const limit = Math.max(1, Math.min(opts.limit ?? DEFAULT_LIMIT, MAX_LIMIT));
    // Public list is VISIBLE-only; the author's own non-visible row is
    // surfaced separately in the EventDetail bundle so this list stays
    // a clean public surface.
    const rows = await this.prisma.eventReview.findMany({
      where: { eventCardId, status: 'VISIBLE' },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(opts.cursor
        ? { cursor: { id: opts.cursor }, skip: 1 }
        : {}),
      include: { user: { include: { profile: true } } },
    });
    const hasMore = rows.length > limit;
    const sliced = hasMore ? rows.slice(0, limit) : rows;

    const agg = await this.prisma.eventReview.aggregate({
      where: { eventCardId, status: 'VISIBLE' },
      _avg: { rating: true },
      _count: { _all: true },
    });

    return {
      items: sliced.map(this.toDTO),
      next_cursor: hasMore ? sliced[sliced.length - 1].id : null,
      average_rating: agg._avg.rating ?? null,
      total: agg._count._all ?? 0,
    };
  }

  /** Used by EventDetailService.getBundle to surface top reviews inline. */
  async topForEvent(
    eventCardId: string,
    limit = 3,
  ): Promise<EventReviewDTO[]> {
    const rows = await this.prisma.eventReview.findMany({
      where: { eventCardId, status: 'VISIBLE' },
      orderBy: [{ createdAt: 'desc' }],
      take: limit,
      include: { user: { include: { profile: true } } },
    });
    return rows.map(this.toDTO);
  }

  private _assertRating(rating: number): void {
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      throw new BadRequestException('rating must be an integer 1..5');
    }
  }

  private toDTO = (row: {
    id: string;
    eventCardId: string;
    userId: string;
    rating: number;
    body: string;
    status: string;
    createdAt: Date;
    updatedAt: Date;
    user?: { profile: { nickname: string | null } | null } | null;
  }): EventReviewDTO => ({
    id: row.id,
    event_card_id: row.eventCardId,
    user: {
      id: row.userId,
      nickname: row.user?.profile?.nickname ?? null,
    },
    rating: row.rating,
    body: row.body,
    status: row.status,
    created_at: row.createdAt.toISOString(),
    updated_at: row.updatedAt.toISOString(),
  });
}
