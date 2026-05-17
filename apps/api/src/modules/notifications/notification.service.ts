import { Inject, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService, Viewer } from '../../shared/access-control.service';
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
  ) {}

  deliveryMode(): string {
    return this.delivery.mode();
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

    // Filter notifications whose spaceAccessPolicy is not allowed for viewer.
    const visible = rows.filter((n) => {
      const p = n.payload as Record<string, unknown>;
      const policy = p['spaceAccessPolicy'] as string | undefined;
      return !policy || allowed.includes(policy);
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
  }): NotificationDTO {
    return {
      id: n.id,
      type: n.type,
      is_read: n.isRead,
      payload: n.payload as Record<string, unknown>,
      created_at: n.createdAt.toISOString(),
    };
  }
}
