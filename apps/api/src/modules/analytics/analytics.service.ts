import {
  ForbiddenException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { Viewer } from '../../shared/access-control.service';

/**
 * First-party analytics taxonomy (M19).
 *
 * Each captured server-side event lands in the `analytics_events` table.
 * Payloads are intentionally MINIMAL and PRIVACY-CONSCIOUS — never put
 * post bodies, reply bodies, message text, email addresses, or any other
 * user-generated content here. IDs and counts only.
 */
export type EventType =
  | 'AUTH_LOGIN'
  | 'AUTH_SIGNUP'
  | 'POST_CREATED'
  | 'REPLY_CREATED'
  | 'ROOM_FOLLOWED'
  | 'ROOM_UNFOLLOWED'
  | 'ITEM_SAVED'
  | 'ITEM_UNSAVED'
  | 'NOTIFICATION_READ'
  | 'REPORT_CREATED'
  | 'MEDIA_UPLOADED'
  | 'EVENT_DETAIL_VIEWED'
  | 'EVENT_RSVP_CHANGED'
  | 'EVENT_UPDATED_NOTIFY'
  | 'RECRUITMENT_APPLIED'
  | 'RECRUITMENT_DECISION_MADE'
  | 'EVENT_REVIEW_CREATED'
  | 'AUTO_MODERATION_TRIGGERED'
  | 'SEARCH_QUERY'
  | 'PROFILE_SHARED'
  | 'USER_MENTIONED'
  | 'POLL_VOTED'
  | 'POST_BOOSTED'
  | 'EVENT_LIVE_POSTED';

export interface EventInput {
  actorId?: string | null;
  eventType: EventType;
  payload?: Record<string, unknown>;
}

export interface EventCountRow {
  event_type: string;
  count: number;
}

@Injectable()
export class AnalyticsService {
  private readonly log = new Logger(AnalyticsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Fire-and-forget event capture. Callers should NEVER `await` this —
   * the helper catches any DB failure and logs a warning so the main
   * business transaction (post create, login, etc.) is never blocked.
   */
  record(input: EventInput): void {
    void this.recordSafely(input);
  }

  private async recordSafely(input: EventInput): Promise<void> {
    try {
      const safePayload = this.scrubPayload(input.payload ?? {});
      await this.prisma.analyticsEvent.create({
        data: {
          actorId: input.actorId ?? null,
          eventType: input.eventType,
          payload: safePayload as object,
        },
      });
    } catch (e) {
      this.log.warn(
        `analytics ${input.eventType} failed: ${e instanceof Error ? e.message : String(e)}`,
      );
    }
  }

  /** Admin-only counts grouped by event_type within a 30-day window. */
  async summarize(viewer: Viewer): Promise<{ window_days: 30; counts: EventCountRow[] }> {
    if (
      !viewer.roles.includes('ADMIN') &&
      !viewer.roles.includes('MODERATOR') &&
      !viewer.roles.includes('CURATOR')
    ) {
      throw new ForbiddenException('Analytics summary requires ops role');
    }
    const since = new Date(Date.now() - 30 * 86_400_000);
    const grouped = await this.prisma.analyticsEvent.groupBy({
      by: ['eventType'],
      where: { createdAt: { gte: since } },
      _count: { eventType: true },
      orderBy: { eventType: 'asc' },
    });
    return {
      window_days: 30,
      counts: grouped.map((g) => ({
        event_type: g.eventType,
        count: g._count.eventType,
      })),
    };
  }

  /**
   * Defense in depth: drop any payload keys that look like content bodies
   * or PII even if a caller passes them by mistake. Truncate string values
   * to keep payloads small.
   */
  private scrubPayload(input: Record<string, unknown>): Record<string, unknown> {
    const FORBIDDEN_KEYS = [
      'body',
      'message',
      'content',
      'email',
      'phone',
      'password',
      'token',
      'access_token',
    ];
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(input)) {
      const keyLower = k.toLowerCase();
      if (FORBIDDEN_KEYS.some((f) => keyLower.includes(f))) continue;
      if (typeof v === 'string') {
        out[k] = v.length > 120 ? `${v.slice(0, 120)}…` : v;
      } else if (
        typeof v === 'number' ||
        typeof v === 'boolean' ||
        v === null
      ) {
        out[k] = v;
      } else if (Array.isArray(v)) {
        out[k] = v.slice(0, 10);
      }
      // skip objects entirely — keep payload flat
    }
    return out;
  }
}
