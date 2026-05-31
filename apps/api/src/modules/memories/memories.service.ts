import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import {
  AccessControlService,
  Viewer,
} from '../../shared/access-control.service';

export type MemoryKind =
  | 'ROOM_FOLLOW'
  | 'CONTRIBUTION_APPROVED'
  | 'EVENT_RSVP';

export interface MemoryItemDTO {
  kind: MemoryKind;
  years_ago: number;
  acted_at: string;
  title: string;
  subtitle: string;
  deep_link: string;
}

export interface MemoriesDTO {
  date: string;
  items: MemoryItemDTO[];
}

// "1년 전 / 2년 전 오늘" — we look back exactly one and two calendar
// years. Three is diminishing returns for a young product; bump
// YEARS_BACK once there's enough history to justify it.
const YEARS_BACK = [1, 2];
const PER_SOURCE_CAP = 20;

/**
 * P6.11 — Topic Hub Memory ("오늘의 기록").
 *
 * Surfaces a user's own anniversary activity — what they did on this
 * calendar day 1 and 2 years ago — so the accumulation of their
 * knowledge engagement becomes tangible (the FB-Memories idea, bent to
 * Club's knowledge/event identity rather than generic social posts).
 *
 * No new schema: every item is derived from existing rows
 * (RoomFollow.createdAt, KnowledgeContribution.resolvedAt for APPROVED,
 * EventRsvp.createdAt). Every source query is visibility-gated so a
 * since-hidden room or a since-restricted hub never leaks into a
 * memory card. SavedItem is intentionally excluded for now — its
 * target (post/reference) can be independently hidden/deleted and
 * resolving that safely is a follow-up.
 *
 * Empty days return `{ items: [] }`; the mobile card self-hides.
 */
@Injectable()
export class MemoriesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
  ) {}

  async getForUser(
    viewer: Viewer & { id: string },
    dateInput?: string,
  ): Promise<MemoriesDTO> {
    const baseDate = this._parseDate(dateInput);
    const allowed = this.access.accessPoliciesAllowedFor(viewer);

    const items: MemoryItemDTO[] = [];
    for (const yearsAgo of YEARS_BACK) {
      const { start, end } = this._anniversaryWindow(baseDate, yearsAgo);
      const [follows, contributions, rsvps] = await Promise.all([
        this._roomFollows(viewer.id, allowed, start, end, yearsAgo),
        this._contributions(viewer.id, allowed, start, end, yearsAgo),
        this._eventRsvps(viewer.id, start, end, yearsAgo),
      ]);
      items.push(...follows, ...contributions, ...rsvps);
    }

    // Most recent anniversary moment first.
    items.sort((a, b) => b.acted_at.localeCompare(a.acted_at));

    return {
      date: this._toDateString(baseDate),
      items,
    };
  }

  // ---- Sources -----------------------------------------------------

  private async _roomFollows(
    userId: string,
    allowed: string[],
    start: Date,
    end: Date,
    yearsAgo: number,
  ): Promise<MemoryItemDTO[]> {
    const rows = await this.prisma.roomFollow.findMany({
      where: {
        userId,
        createdAt: { gte: start, lt: end },
        room: {
          status: 'ACTIVE',
          category: { space: { accessPolicy: { in: allowed } } },
        },
      },
      include: { room: true },
      orderBy: { createdAt: 'desc' },
      take: PER_SOURCE_CAP,
    });
    return rows.map((r) => ({
      kind: 'ROOM_FOLLOW' as const,
      years_ago: yearsAgo,
      acted_at: r.createdAt.toISOString(),
      title: r.room.name,
      subtitle: `${yearsAgo}년 전 오늘 이 방을 팔로우했어요`,
      deep_link: `/rooms/${r.room.slug}`,
    }));
  }

  private async _contributions(
    userId: string,
    allowed: string[],
    start: Date,
    end: Date,
    yearsAgo: number,
  ): Promise<MemoryItemDTO[]> {
    const rows = await this.prisma.knowledgeContribution.findMany({
      where: {
        contributorId: userId,
        status: 'APPROVED',
        resolvedAt: { gte: start, lt: end },
        hub: { category: { space: { accessPolicy: { in: allowed } } } },
      },
      include: { hub: { include: { category: true } } },
      orderBy: { resolvedAt: 'desc' },
      take: PER_SOURCE_CAP,
    });
    return rows
      .filter((r) => r.resolvedAt != null)
      .map((r) => ({
        kind: 'CONTRIBUTION_APPROVED' as const,
        years_ago: yearsAgo,
        acted_at: (r.resolvedAt as Date).toISOString(),
        title: r.proposedTitle,
        subtitle: `${yearsAgo}년 전 오늘 이 지식 기여가 승인됐어요`,
        deep_link: `/categories/${r.hub.category.slug}`,
      }));
  }

  private async _eventRsvps(
    userId: string,
    start: Date,
    end: Date,
    yearsAgo: number,
  ): Promise<MemoryItemDTO[]> {
    const rows = await this.prisma.eventRsvp.findMany({
      where: {
        userId,
        createdAt: { gte: start, lt: end },
      },
      include: { eventCard: true },
      orderBy: { createdAt: 'desc' },
      take: PER_SOURCE_CAP,
    });
    return rows.map((r) => ({
      kind: 'EVENT_RSVP' as const,
      years_ago: yearsAgo,
      acted_at: r.createdAt.toISOString(),
      title: r.eventCard.title,
      subtitle: `${yearsAgo}년 전 오늘 이 이벤트에 관심을 보였어요`,
      deep_link: `/events/${r.eventCard.id}`,
    }));
  }

  // ---- Date helpers ------------------------------------------------

  private _parseDate(input?: string): Date {
    if (input) {
      const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(input);
      if (m) {
        return new Date(
          Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])),
        );
      }
    }
    const now = new Date();
    return new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
    );
  }

  /**
   * The same calendar day `yearsAgo` years before `base`, as a 24h
   * UTC window. Using the same month/day (not "exactly 365 days")
   * keeps the anniversary aligned across leap years.
   */
  private _anniversaryWindow(
    base: Date,
    yearsAgo: number,
  ): { start: Date; end: Date } {
    const start = new Date(
      Date.UTC(
        base.getUTCFullYear() - yearsAgo,
        base.getUTCMonth(),
        base.getUTCDate(),
      ),
    );
    const end = new Date(start.getTime() + 24 * 60 * 60 * 1000);
    return { start, end };
  }

  private _toDateString(d: Date): string {
    const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
    const dd = String(d.getUTCDate()).padStart(2, '0');
    return `${d.getUTCFullYear()}-${mm}-${dd}`;
  }
}
