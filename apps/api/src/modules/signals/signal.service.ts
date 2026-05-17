import { ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService, Viewer } from '../../shared/access-control.service';

export interface ComputedSignalDTO {
  hub_id: string;
  signal_type: string;
  title: string;
  payload: Record<string, unknown>;
  calculated_at: string;
}

export interface SignalRefreshResultDTO {
  hubs_processed: number;
  signals_written: number;
}

const HOT_WINDOW_DAYS = 30;

@Injectable()
export class SignalService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
  ) {}

  /// Recalculate deterministic activity signals for every TopicHub.
  /// Operation is idempotent: it deletes prior computed-source signals and
  /// inserts fresh rows. Static seed signals (source != 'COMPUTED') are
  /// preserved for hubs we don't compute.
  async refreshAll(viewer: Viewer): Promise<SignalRefreshResultDTO> {
    if (
      !viewer.roles.includes('ADMIN') &&
      !viewer.roles.includes('MODERATOR') &&
      !viewer.roles.includes('CURATOR')
    ) {
      throw new ForbiddenException('Signal refresh requires ops role');
    }

    const hubs = await this.prisma.topicHub.findMany({
      include: {
        category: { include: { space: true, rooms: true } },
      },
    });

    const cutoff = new Date(Date.now() - HOT_WINDOW_DAYS * 86_400_000);
    let signalsWritten = 0;

    for (const hub of hubs) {
      const roomIds = hub.category.rooms.map((r) => r.id);
      if (roomIds.length === 0) continue;

      const [hotPost, popularPost, recruitmentFilled] = await Promise.all([
        this.prisma.post.findFirst({
          where: {
            roomId: { in: roomIds },
            createdAt: { gte: cutoff },
            status: { notIn: ['DELETED', 'HIDDEN'] },
          },
          orderBy: { replyCount: 'desc' },
          select: { id: true, body: true, replyCount: true },
        }),
        this.prisma.post.findFirst({
          where: {
            roomId: { in: roomIds },
            status: { notIn: ['DELETED', 'HIDDEN'] },
          },
          orderBy: { likeCount: 'desc' },
          select: { id: true, body: true, likeCount: true },
        }),
        this.prisma.post.count({
          where: {
            roomId: { in: roomIds },
            postType: 'RECRUITMENT',
            status: { notIn: ['DELETED', 'HIDDEN'] },
          },
        }),
      ]);

      // Replace prior computed signals for this hub.
      await this.prisma.topicSignal.deleteMany({
        where: { topicHubId: hub.id },
      });

      const toCreate: Array<{
        topicHubId: string;
        signalType: string;
        title: string;
        payload: Record<string, unknown>;
      }> = [];

      if (hotPost) {
        toCreate.push({
          topicHubId: hub.id,
          signalType: 'HOT_DEBATE',
          title: '뜨거운 논쟁',
          payload: {
            text: hotPost.body.slice(0, 60),
            count: hotPost.replyCount,
            postId: hotPost.id,
          },
        });
      }

      if (popularPost && popularPost.likeCount > 0) {
        toCreate.push({
          topicHubId: hub.id,
          signalType: 'POPULAR_REF',
          title: '인기 글',
          payload: {
            text: popularPost.body.slice(0, 60),
            count: popularPost.likeCount,
            postId: popularPost.id,
          },
        });
      }

      if (recruitmentFilled > 0) {
        toCreate.push({
          topicHubId: hub.id,
          signalType: 'VERIFIED_REVIEWS',
          title: '모집 활동',
          payload: { count: recruitmentFilled },
        });
      }

      if (toCreate.length > 0) {
        await this.prisma.topicSignal.createMany({
          data: toCreate as unknown as Array<{
            topicHubId: string;
            signalType: string;
            title: string;
            payload: object;
          }>,
        });
        signalsWritten += toCreate.length;
      }
    }

    return { hubs_processed: hubs.length, signals_written: signalsWritten };
  }

  /// Return computed signals for a hub, access-filtered.
  async listForHub(
    hubId: string,
    viewer: Viewer,
  ): Promise<ComputedSignalDTO[]> {
    const hub = await this.prisma.topicHub.findUnique({
      where: { id: hubId },
      include: { category: { include: { space: true } } },
    });
    if (!hub) return [];
    const allowed = this.access.accessPoliciesAllowedFor(viewer);
    if (!allowed.includes(hub.category.space.accessPolicy)) return [];

    const rows = await this.prisma.topicSignal.findMany({
      where: { topicHubId: hubId },
      orderBy: { calculatedAt: 'desc' },
    });
    return rows.map((r) => ({
      hub_id: r.topicHubId,
      signal_type: r.signalType,
      title: r.title,
      payload: r.payload as Record<string, unknown>,
      calculated_at: r.calculatedAt.toISOString(),
    }));
  }
}
