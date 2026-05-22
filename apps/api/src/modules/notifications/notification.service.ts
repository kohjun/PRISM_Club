import { Inject, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService, Viewer } from '../../shared/access-control.service';
import { BlockMuteService } from '../../shared/block-mute.service';
import { AnalyticsService } from '../analytics/analytics.service';
import {
  DeliveryAttempt,
  DeliveryRequest,
  INotificationDeliverer,
  NOTIFICATION_DELIVERY,
} from './delivery/notification-delivery.interface';
import {
  NotificationDTO,
  NotificationListDTO,
  UnreadCountDTO,
} from './dto/notification.dto';

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;
// P6.3 grouping window. Anything older than this gets a fresh row.
const GROUP_WINDOW_MS = 60 * 60 * 1000;
// Beyond this many actors we surface "외 N명" via `payload.actors_overflow`.
const ACTORS_CAP = 10;

export interface ListOpts {
  cursor?: string;
  limit?: number;
  unreadOnly?: boolean;
}

@Injectable()
export class NotificationService {
  private readonly log = new Logger(NotificationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
    @Inject(NOTIFICATION_DELIVERY)
    private readonly delivery: INotificationDeliverer,
    private readonly analytics: AnalyticsService,
    private readonly blockMute: BlockMuteService,
  ) {}

  deliveryMode(): string {
    return this.delivery.mode();
  }

  /**
   * P6.3 grouping-aware notification creation.
   *
   * Single-row writes that share a `(userId, groupKey)` within a 1h
   * window are coalesced — the actor is appended to `payload.actors`
   * (deduped, cap 10), the row is marked unread, and `updatedAt`
   * bumps so the recipient sees the merged row re-surface at the top
   * of their inbox.
   *
   * Passing `groupKey: null` (the default) preserves the old
   * "one row per call" behaviour — used by mentions / digests /
   * reminders where each event is a discrete signal.
   *
   * Callers pass `actorId` (the user who triggered the notification);
   * we copy it into `payload.actorId` so the existing block/mute
   * filter in `listForUser` keeps working without a per-type branch.
   */
  async createOrGroup(input: {
    userId: string;
    type: string;
    payload: Record<string, unknown>;
    actorId?: string;
    groupKey?: string | null;
  }): Promise<void> {
    const { userId, type, payload, actorId, groupKey } = input;
    // Stamp actorId into payload so the unified filter sees it.
    const enrichedPayload: Record<string, unknown> = {
      ...payload,
      ...(actorId ? { actorId } : {}),
      actors: actorId
        ? [...((payload.actors as string[] | undefined) ?? []), actorId]
        : (payload.actors as string[] | undefined) ?? [],
    };

    if (!groupKey) {
      await this.prisma.notification.create({
        data: {
          userId,
          type,
          payload: enrichedPayload as Prisma.InputJsonValue,
          groupKey: null,
        },
      });
      return;
    }

    const cutoff = new Date(Date.now() - GROUP_WINDOW_MS);
    const existing = await this.prisma.notification.findFirst({
      where: {
        userId,
        groupKey,
        isRead: false,
        createdAt: { gte: cutoff },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (existing) {
      const prevPayload = (existing.payload as Record<string, unknown>) ?? {};
      const prevActors = Array.isArray(prevPayload.actors)
        ? (prevPayload.actors as string[])
        : [];
      // Merge actors: keep insertion order, dedupe, cap. Cap is soft
      // — beyond the cap we still count via `actors_overflow`.
      const merged: string[] = [...prevActors];
      if (actorId && !merged.includes(actorId)) {
        merged.push(actorId);
      }
      const overflow = Math.max(0, merged.length - ACTORS_CAP);
      const capped = overflow > 0 ? merged.slice(-ACTORS_CAP) : merged;
      const nextPayload: Record<string, unknown> = {
        ...prevPayload,
        ...payload,
        actors: capped,
        actors_overflow: overflow,
        ...(actorId ? { actorId } : {}),
      };
      await this.prisma.notification.update({
        where: { id: existing.id },
        data: {
          payload: nextPayload as Prisma.InputJsonValue,
          updatedAt: new Date(),
        },
      });
      return;
    }

    await this.prisma.notification.create({
      data: {
        userId,
        type,
        payload: enrichedPayload as Prisma.InputJsonValue,
        groupKey,
      },
    });
  }

  /**
   * Fire-and-forget delivery dispatch. Triggering services (ReplyService,
   * PostService.create, etc.) can call this after writing notification
   * rows to fan out to email / push. Errors are swallowed and logged —
   * the caller never has to await or handle a rejection.
   */
  dispatchDelivery(req: DeliveryRequest): void {
    void this.deliverSafely(req);
  }

  private async deliverSafely(
    req: DeliveryRequest,
  ): Promise<DeliveryAttempt[]> {
    try {
      const attempts = await this.delivery.deliver(req);
      const failed = attempts.filter((a) => a.status === 'FAILED');
      if (failed.length > 0) {
        this.log.warn(
          `notification[${req.type}] delivery had ${failed.length} failed channel(s): ${failed
            .map((f) => `${f.channel}=${f.error ?? '-'}`)
            .join('; ')}`,
        );
      }
      return attempts;
    } catch (e) {
      this.log.warn(
        `notification[${req.type}] deliverer threw (${e instanceof Error ? e.message : String(e)}); swallowing`,
      );
      return [];
    }
  }

  async listForUser(
    userId: string,
    viewer: Viewer,
    opts: ListOpts = {},
  ): Promise<NotificationListDTO> {
    const allowed = this.access.accessPoliciesAllowedFor(viewer);
    const limit = Math.max(1, Math.min(opts.limit ?? DEFAULT_LIMIT, MAX_LIMIT));

    const rows = await this.prisma.notification.findMany({
      where: {
        userId,
        ...(opts.unreadOnly ? { isRead: false } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
      ...(opts.cursor ? { cursor: { id: opts.cursor }, skip: 1 } : {}),
    });

    // First pass: drop notifications whose spaceAccessPolicy is no
    // longer allowed for viewer.
    const policyFiltered = rows.filter((n) => {
      const p = n.payload as Record<string, unknown>;
      const policy = p['spaceAccessPolicy'] as string | undefined;
      return !policy || allowed.includes(policy);
    });

    // P6.2: drop notifications whose actor (payload.actorId, populated
    // by mention / reply / quote / boost paths) is in a block or mute
    // relationship with viewer. We resolve actor ids in one bulk call
    // so the per-row check stays O(1).
    const actorIds = Array.from(
      new Set(
        policyFiltered
          .map((n) => (n.payload as Record<string, unknown>)['actorId'])
          .filter((v): v is string => typeof v === 'string'),
      ),
    );
    const [blockedSet, mutedSet] = await Promise.all([
      this.blockMute.blockedSetFor(userId, actorIds),
      this.blockMute.mutedSetFor(userId, actorIds),
    ]);
    const visible = policyFiltered.filter((n) => {
      const actorId = (n.payload as Record<string, unknown>)['actorId'];
      if (typeof actorId !== 'string') return true;
      return !blockedSet.has(actorId) && !mutedSet.has(actorId);
    });

    const hasMore = visible.length > limit;
    const sliced = hasMore ? visible.slice(0, limit) : visible;
    const unreadCount = await this.getUnreadCount(userId);

    return {
      items: sliced.map(this.toDTO),
      next_cursor: hasMore ? sliced[sliced.length - 1].id : null,
      unread_count: unreadCount.count,
    };
  }

  async markRead(id: string, userId: string): Promise<{ ok: boolean }> {
    const row = await this.prisma.notification.findFirst({ where: { id, userId } });
    if (!row) throw new NotFoundException(`Notification not found: ${id}`);
    await this.prisma.notification.update({ where: { id }, data: { isRead: true } });
    this.analytics.record({
      actorId: userId,
      eventType: 'NOTIFICATION_READ',
      payload: { notification_id: id, notif_type: row.type },
    });
    return { ok: true };
  }

  async markAllRead(userId: string): Promise<{ updated_count: number }> {
    const result = await this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });
    return { updated_count: result.count };
  }

  async getUnreadCount(userId: string): Promise<UnreadCountDTO> {
    const count = await this.prisma.notification.count({
      where: { userId, isRead: false },
    });
    return { count };
  }

  private toDTO(n: {
    id: string;
    type: string;
    isRead: boolean;
    payload: unknown;
    createdAt: Date;
    updatedAt: Date;
  }): NotificationDTO {
    return {
      id: n.id,
      type: n.type,
      is_read: n.isRead,
      payload: n.payload as Record<string, unknown>,
      created_at: n.createdAt.toISOString(),
      updated_at: n.updatedAt.toISOString(),
    };
  }
}
