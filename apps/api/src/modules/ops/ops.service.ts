import { ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { Viewer } from '../../shared/access-control.service';

export interface OpsSummaryDTO {
  pending_contributions: { count: number };
  open_reports: { count: number };
  recruitment_posts: { count_open: number; count_total: number };
  recent_users: { count: number; items: Array<{ id: string; nickname: string | null; created_at: string }> };
  recent_rooms: { count: number; items: Array<{ id: string; slug: string; name: string; created_at: string }> };
  recent_posts: { count: number; items: Array<{ id: string; body_preview: string; room_slug: string; created_at: string }> };
  // P6.9: scoped-DM moderation visibility (closed channels are a
  // potential moderation blind spot — surface report volume + live load).
  dm: { reports_24h: number; channels_open: number };
}

const RECENT_WINDOW_DAYS = 30;
const RECENT_TAKE = 5;

@Injectable()
export class OpsService {
  constructor(private readonly prisma: PrismaService) {}

  private isAuthorized(viewer: Viewer): boolean {
    return (
      viewer.roles.includes('ADMIN') ||
      viewer.roles.includes('MODERATOR') ||
      viewer.roles.includes('CURATOR')
    );
  }

  async getSummary(viewer: Viewer): Promise<OpsSummaryDTO> {
    if (!this.isAuthorized(viewer)) {
      throw new ForbiddenException('Ops dashboard requires CURATOR/MODERATOR/ADMIN role');
    }

    const since = new Date(Date.now() - RECENT_WINDOW_DAYS * 86_400_000);
    const since24h = new Date(Date.now() - 86_400_000);

    const [
      pendingContribs,
      openReports,
      recruitmentOpen,
      recruitmentTotal,
      recentUserCount,
      recentUserRows,
      recentRoomCount,
      recentRoomRows,
      recentPostCount,
      recentPostRows,
      dmReports24h,
      dmChannelsOpen,
    ] = await Promise.all([
      this.prisma.knowledgeContribution.count({ where: { status: 'PENDING' } }),
      this.prisma.report.count({ where: { status: 'OPEN' } }),
      this.prisma.post.count({
        where: {
          postType: 'RECRUITMENT',
          status: { notIn: ['DELETED', 'HIDDEN'] },
          recruitmentFields: { path: ['status'], equals: 'OPEN' },
        },
      }),
      this.prisma.post.count({
        where: {
          postType: 'RECRUITMENT',
          status: { notIn: ['DELETED', 'HIDDEN'] },
        },
      }),
      this.prisma.user.count({ where: { createdAt: { gte: since } } }),
      this.prisma.user.findMany({
        where: { createdAt: { gte: since } },
        orderBy: { createdAt: 'desc' },
        take: RECENT_TAKE,
        include: { profile: true },
      }),
      this.prisma.room.count({ where: { createdAt: { gte: since } } }),
      this.prisma.room.findMany({
        where: { createdAt: { gte: since } },
        orderBy: { createdAt: 'desc' },
        take: RECENT_TAKE,
      }),
      this.prisma.post.count({
        where: {
          createdAt: { gte: since },
          status: { notIn: ['DELETED', 'HIDDEN'] },
        },
      }),
      this.prisma.post.findMany({
        where: {
          createdAt: { gte: since },
          status: { notIn: ['DELETED', 'HIDDEN'] },
        },
        orderBy: { createdAt: 'desc' },
        take: RECENT_TAKE,
        include: { room: true },
      }),
      this.prisma.report.count({
        where: { targetType: 'DM_MESSAGE', createdAt: { gte: since24h } },
      }),
      this.prisma.dmChannel.count({ where: { status: 'OPEN' } }),
    ]);

    return {
      pending_contributions: { count: pendingContribs },
      open_reports: { count: openReports },
      recruitment_posts: {
        count_open: recruitmentOpen,
        count_total: recruitmentTotal,
      },
      recent_users: {
        count: recentUserCount,
        items: recentUserRows.map((u) => ({
          id: u.id,
          nickname: u.profile?.nickname ?? null,
          created_at: u.createdAt.toISOString(),
        })),
      },
      recent_rooms: {
        count: recentRoomCount,
        items: recentRoomRows.map((r) => ({
          id: r.id,
          slug: r.slug,
          name: r.name,
          created_at: r.createdAt.toISOString(),
        })),
      },
      recent_posts: {
        count: recentPostCount,
        items: recentPostRows.map((p) => ({
          id: p.id,
          body_preview: p.body.slice(0, 80),
          room_slug: p.room.slug,
          created_at: p.createdAt.toISOString(),
        })),
      },
      dm: { reports_24h: dmReports24h, channels_open: dmChannelsOpen },
    };
  }
}
