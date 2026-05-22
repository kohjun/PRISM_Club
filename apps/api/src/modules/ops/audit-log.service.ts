import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma.service';

const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 200;

const CURATED_ANALYTICS_TYPES = new Set([
  'AUTH_LOGIN',
  'AUTH_SIGNUP',
  'REPORT_CREATED',
  'EVENT_RSVP_CHANGED',
  'RECRUITMENT_APPLIED',
  'RECRUITMENT_DECISION_MADE',
  'EVENT_REVIEW_CREATED',
]);

export type AuditEntrySource = 'MODERATION' | 'ANALYTICS';

export interface AuditEntryDTO {
  id: string;
  source: AuditEntrySource;
  actor: { id: string | null; nickname: string | null };
  action: string;
  target_type: string | null;
  target_id: string | null;
  note: string | null;
  payload: Record<string, unknown> | null;
  occurred_at: string;
}

export interface AuditLogPageDTO {
  items: AuditEntryDTO[];
  next_cursor: string | null;
}

interface ListOpts {
  actorId?: string;
  targetType?: string;
  targetId?: string;
  action?: string;
  from?: Date;
  to?: Date;
  cursor?: string;
  limit?: number;
}

/**
 * P5.4 audit-log service.
 *
 * Composes a union over `moderation_actions` (always shown) and a
 * curated subset of `analytics_events` (only operationally interesting
 * types) so admins get a single timeline of "who did what". Cursor
 * format is `${source}:${id}` so paging through the merged stream is
 * stable.
 */
@Injectable()
export class AuditLogService {
  constructor(private readonly prisma: PrismaService) {}

  async list(opts: ListOpts): Promise<AuditLogPageDTO> {
    const limit = Math.max(1, Math.min(opts.limit ?? DEFAULT_LIMIT, MAX_LIMIT));

    // Cursor decoding. New callers send raw row id (we tag source at
    // emit time). Empty cursor → first page.
    let cursor: { source: AuditEntrySource; id: string } | null = null;
    if (opts.cursor) {
      const [source, id] = opts.cursor.split(':');
      if ((source === 'MODERATION' || source === 'ANALYTICS') && id) {
        cursor = { source, id };
      }
    }

    const modWhere: Prisma.ModerationActionWhereInput = {
      ...(opts.actorId ? { actorId: opts.actorId } : {}),
      ...(opts.targetType ? { targetType: opts.targetType } : {}),
      ...(opts.targetId ? { targetId: opts.targetId } : {}),
      ...(opts.action ? { action: opts.action } : {}),
      ...(opts.from || opts.to
        ? {
            createdAt: {
              ...(opts.from ? { gte: opts.from } : {}),
              ...(opts.to ? { lte: opts.to } : {}),
            },
          }
        : {}),
    };
    const anaWhere: Prisma.AnalyticsEventWhereInput = {
      eventType: { in: [...CURATED_ANALYTICS_TYPES] },
      ...(opts.actorId ? { actorId: opts.actorId } : {}),
      ...(opts.action ? { eventType: opts.action } : {}),
      ...(opts.from || opts.to
        ? {
            createdAt: {
              ...(opts.from ? { gte: opts.from } : {}),
              ...(opts.to ? { lte: opts.to } : {}),
            },
          }
        : {}),
    };

    // Pull `limit + 1` of each side; merge by createdAt desc; trim.
    const fetchSize = limit + 1;
    const [modRows, anaRows] = await Promise.all([
      this.prisma.moderationAction.findMany({
        where: modWhere,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: fetchSize,
        include: { actor: { include: { profile: true } } },
      }),
      this.prisma.analyticsEvent.findMany({
        where: anaWhere,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: fetchSize,
      }),
    ]);

    const all: AuditEntryDTO[] = [
      ...modRows.map((r) => this.modToDTO(r)),
      ...anaRows.map((r) => this.anaToDTO(r)),
    ];
    all.sort(
      (a, b) =>
        new Date(b.occurred_at).getTime() -
        new Date(a.occurred_at).getTime(),
    );

    // Apply cursor by dropping entries up to (and including) the cursor's id.
    let trimmed = all;
    if (cursor) {
      const cutoffIdx = trimmed.findIndex(
        (e) => e.source === cursor!.source && e.id === cursor!.id,
      );
      if (cutoffIdx >= 0) {
        trimmed = trimmed.slice(cutoffIdx + 1);
      }
    }

    const hasMore = trimmed.length > limit;
    const items = hasMore ? trimmed.slice(0, limit) : trimmed;
    return {
      items,
      next_cursor: hasMore
        ? `${items[items.length - 1].source}:${items[items.length - 1].id}`
        : null,
    };
  }

  /**
   * CSV streaming — same filter set, but unbounded by cursor. Caller
   * is expected to narrow with `from/to` to keep the export
   * manageable; controller hard-caps at 10k rows.
   */
  async listCsv(
    opts: Omit<ListOpts, 'cursor' | 'limit'> & { hardCap: number },
  ): Promise<AuditEntryDTO[]> {
    const page = await this.list({ ...opts, limit: opts.hardCap });
    return page.items;
  }

  private modToDTO(r: {
    id: string;
    actorId: string;
    action: string;
    targetType: string;
    targetId: string;
    note: string | null;
    createdAt: Date;
    actor: { profile: { nickname: string | null } | null } | null;
  }): AuditEntryDTO {
    return {
      id: r.id,
      source: 'MODERATION',
      actor: {
        id: r.actorId,
        nickname: r.actor?.profile?.nickname ?? null,
      },
      action: r.action,
      target_type: r.targetType,
      target_id: r.targetId,
      note: r.note,
      payload: null,
      occurred_at: r.createdAt.toISOString(),
    };
  }

  private anaToDTO(r: {
    id: string;
    actorId: string | null;
    eventType: string;
    payload: unknown;
    createdAt: Date;
  }): AuditEntryDTO {
    return {
      id: r.id,
      source: 'ANALYTICS',
      actor: { id: r.actorId, nickname: null },
      action: r.eventType,
      target_type: null,
      target_id: null,
      note: null,
      payload: r.payload as Record<string, unknown>,
      occurred_at: r.createdAt.toISOString(),
    };
  }
}
