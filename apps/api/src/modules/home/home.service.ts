import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService, Viewer } from '../../shared/access-control.service';
import { NotificationService } from '../notifications/notification.service';
import { PostService } from '../posts/post.service';
import {
  HomeBundleDTO,
  HomeFeedItemDTO,
  HomeFeedItemType,
  HomeFeedPageDTO,
  TopicHubSummaryDTO,
} from './dto/home.dto';
import { SavedItemDTO } from '../saves/save.service';
import { RoomSummaryDTO, EventCardDTO } from '../community/dto/room.dto';

const POST_INCLUDE = {
  room: true,
  author: { include: { profile: true } },
  attachments: true,
} as const;

const REASONS: Record<HomeFeedItemType, string> = {
  FOLLOWED_ROOM_POST: '팔로우한 방의 새 글',
  TRENDING_POST: '요즘 인기 있는 글',
  RECOMMENDED_ROOM: '추천 방',
  RECOMMENDED_EVENT: '다가오는 이벤트',
  ACTIVE_HUB: '활성 토픽 허브',
};

type ViewerWithId = Viewer & { id: string };

@Injectable()
export class HomeService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
    private readonly notifications: NotificationService,
    private readonly postService: PostService,
  ) {}

  async getBundle(viewer: ViewerWithId): Promise<HomeBundleDTO> {
    const policies = this.access.accessPoliciesAllowedFor(viewer);

    const [
      followedPostRows,
      recommendedRooms,
      recommendedEvents,
      trendingCandidates,
      activeHubs,
      savedRecently,
      unreadResult,
    ] = await Promise.all([
      this.fetchFollowedRoomPosts(viewer.id, policies),
      this.fetchRecommendedRooms(viewer.id, policies),
      this.fetchRecommendedEvents(),
      this.fetchTrendingCandidates(policies),
      this.fetchActiveHubs(policies),
      this.fetchSavedRecently(viewer.id, policies),
      this.notifications.getUnreadCount(viewer.id),
    ]);

    const trendingRows = trendingCandidates
      .map((p) => ({ ...p, _score: p.likeCount * 3 + p.replyCount * 2 + p.bookmarkCount }))
      .sort((a, b) => b._score - a._score)
      .slice(0, 5);

    const [followedRoomPosts, trendingPosts] = await Promise.all([
      this.postService.postsToDTOs(followedPostRows, viewer.id),
      this.postService.postsToDTOs(trendingRows, viewer.id),
    ]);

    return {
      unread_notification_count: unreadResult.count,
      followed_room_updates: followedRoomPosts,
      recommended_rooms: recommendedRooms,
      recommended_events: recommendedEvents,
      trending_posts: trendingPosts,
      active_topic_hubs: activeHubs,
      saved_recently: savedRecently,
    };
  }

  async getHomeFeed(
    viewer: ViewerWithId,
    cursor?: string,
    limit = 20,
  ): Promise<HomeFeedPageDTO> {
    const policies = this.access.accessPoliciesAllowedFor(viewer);

    const [followedPostRows, recommendedRooms, recommendedEvents, trendingCandidates, activeHubs] =
      await Promise.all([
        this.fetchFollowedRoomPosts(viewer.id, policies),
        this.fetchRecommendedRooms(viewer.id, policies),
        this.fetchRecommendedEvents(),
        this.fetchTrendingCandidates(policies),
        this.fetchActiveHubs(policies),
      ]);

    const trendingRows = trendingCandidates
      .map((p) => ({ ...p, _score: p.likeCount * 3 + p.replyCount * 2 + p.bookmarkCount }))
      .sort((a, b) => b._score - a._score)
      .slice(0, 5);

    const [followedPostDTOs, trendingDTOs] = await Promise.all([
      this.postService.postsToDTOs(followedPostRows, viewer.id),
      this.postService.postsToDTOs(trendingRows, viewer.id),
    ]);

    const allItems: HomeFeedItemDTO[] = [
      ...followedPostDTOs.map((p) => ({
        id: `FOLLOWED_ROOM_POST:${p.id}`,
        type: 'FOLLOWED_ROOM_POST' as HomeFeedItemType,
        reason: REASONS.FOLLOWED_ROOM_POST,
        payload: p,
      })),
      ...trendingDTOs.map((p) => ({
        id: `TRENDING_POST:${p.id}`,
        type: 'TRENDING_POST' as HomeFeedItemType,
        reason: REASONS.TRENDING_POST,
        payload: p,
      })),
      ...recommendedRooms.map((r) => ({
        id: `RECOMMENDED_ROOM:${r.id}`,
        type: 'RECOMMENDED_ROOM' as HomeFeedItemType,
        reason: REASONS.RECOMMENDED_ROOM,
        payload: r,
      })),
      ...recommendedEvents.map((e) => ({
        id: `RECOMMENDED_EVENT:${e.id}`,
        type: 'RECOMMENDED_EVENT' as HomeFeedItemType,
        reason: REASONS.RECOMMENDED_EVENT,
        payload: e,
      })),
      ...activeHubs.map((h) => ({
        id: `ACTIVE_HUB:${h.id}`,
        type: 'ACTIVE_HUB' as HomeFeedItemType,
        reason: REASONS.ACTIVE_HUB,
        payload: h,
      })),
    ];

    let startIndex = 0;
    if (cursor) {
      const cursorId = Buffer.from(cursor, 'base64').toString('utf-8');
      const idx = allItems.findIndex((i) => i.id === cursorId);
      if (idx !== -1) startIndex = idx + 1;
    }

    const pageItems = allItems.slice(startIndex, startIndex + limit);
    const hasMore = startIndex + limit < allItems.length;
    const lastItem = pageItems[pageItems.length - 1];
    const nextCursor =
      hasMore && lastItem ? Buffer.from(lastItem.id).toString('base64') : null;

    return { items: pageItems, next_cursor: nextCursor };
  }

  private async fetchFollowedRoomPosts(userId: string, policies: string[]) {
    const follows = await this.prisma.roomFollow.findMany({ where: { userId } });
    if (follows.length === 0) return [];
    const roomIds = follows.map((f) => f.roomId);
    return this.prisma.post.findMany({
      where: {
        roomId: { in: roomIds },
        status: { notIn: ['DELETED', 'HIDDEN'] },
        room: { category: { space: { accessPolicy: { in: policies } } } },
      },
      orderBy: { createdAt: 'desc' },
      take: 5,
      include: POST_INCLUDE,
    });
  }

  private async fetchRecommendedRooms(userId: string, policies: string[]): Promise<RoomSummaryDTO[]> {
    const follows = await this.prisma.roomFollow.findMany({ where: { userId } });
    const followedIds = new Set(follows.map((f) => f.roomId));

    const rooms = await this.prisma.room.findMany({
      where: { category: { space: { accessPolicy: { in: policies } } } },
      include: {
        _count: { select: { followers: true, posts: true } },
        owner: { include: { profile: true } },
      },
    });

    return rooms
      .filter((r) => !followedIds.has(r.id))
      .map((r) => ({ ...r, _score: r._count.followers * 2 + r._count.posts }))
      .sort((a, b) => b._score - a._score)
      .slice(0, 5)
      .map((r) => ({
        id: r.id,
        slug: r.slug,
        name: r.name,
        description: r.description,
        origin: r.origin as 'OFFICIAL' | 'USER',
        room_type: r.roomType,
        owner_nickname: (r.owner as any)?.profile?.nickname ?? null,
      }));
  }

  private async fetchRecommendedEvents(): Promise<EventCardDTO[]> {
    const cards = await this.prisma.eventCard.findMany({
      where: { startsAt: { gt: new Date() } },
      orderBy: { startsAt: 'asc' },
      take: 3,
    });
    return cards.map((c) => ({
      id: c.id,
      external_event_id: c.externalEventId,
      title: c.title,
      venue_name: c.venueName,
      region: c.region,
      starts_at: c.startsAt.toISOString(),
      event_status: c.eventStatus,
      thumbnail_url: c.thumbnailUrl,
    }));
  }

  private async fetchTrendingCandidates(policies: string[]) {
    return this.prisma.post.findMany({
      where: {
        status: { notIn: ['DELETED', 'HIDDEN'] },
        room: { category: { space: { accessPolicy: { in: policies } } } },
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
      include: POST_INCLUDE,
    });
  }

  private async fetchActiveHubs(policies: string[]): Promise<TopicHubSummaryDTO[]> {
    const hubs = await this.prisma.topicHub.findMany({
      where: {
        blocks: { some: {} },
        category: { space: { accessPolicy: { in: policies } } },
      },
      include: {
        category: true,
        _count: { select: { blocks: true } },
      },
      orderBy: { updatedAt: 'desc' },
      take: 3,
    });
    return hubs.map((h) => ({
      id: h.id,
      category_slug: h.category.slug,
      title: h.title,
      summary: h.summary,
      block_count: h._count.blocks,
      updated_at: h.updatedAt.toISOString(),
    }));
  }

  private async fetchSavedRecently(
    userId: string,
    policies: string[],
  ): Promise<SavedItemDTO[]> {
    const rows = await this.prisma.savedItem.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 3,
    });

    const items: SavedItemDTO[] = [];
    for (const row of rows) {
      const target = await this.resolveTarget(row.targetType, row.targetId, policies);
      if (!target) continue;
      items.push({
        id: row.id,
        target_type: row.targetType as 'POST' | 'REFERENCE' | 'EVENT_CARD',
        target_id: row.targetId,
        saved_at: row.createdAt.toISOString(),
        collection_id: row.collectionId ?? null,
        target,
      });
    }
    return items;
  }

  private async resolveTarget(
    type: string,
    id: string,
    allowed: string[],
  ): Promise<Record<string, unknown> | null> {
    if (type === 'POST') {
      const post = await this.prisma.post.findFirst({
        where: {
          id,
          status: { notIn: ['DELETED', 'HIDDEN'] },
          room: { category: { space: { accessPolicy: { in: allowed } } } },
        },
        include: { room: true, author: { include: { profile: true } } },
      });
      if (!post) return null;
      return {
        id: post.id,
        body_preview: post.body.slice(0, 80),
        room_name: post.room.name,
        room_slug: post.room.slug,
        author_nickname: (post.author as any).profile?.nickname ?? '',
        created_at: post.createdAt.toISOString(),
      };
    }
    if (type === 'REFERENCE') {
      const ref = await this.prisma.reference.findFirst({ where: { id, status: 'VISIBLE' } });
      if (!ref) return null;
      return {
        id: ref.id,
        type: ref.type,
        url: ref.url,
        title: ref.title,
        source_name: ref.sourceName,
        thumbnail_url: ref.thumbnailUrl,
        summary: ref.summary,
      };
    }
    if (type === 'EVENT_CARD') {
      const card = await this.prisma.eventCard.findUnique({ where: { id } });
      if (!card) return null;
      return {
        id: card.id,
        title: card.title,
        venue_name: card.venueName,
        region: card.region,
        starts_at: card.startsAt.toISOString(),
        event_status: card.eventStatus,
        thumbnail_url: card.thumbnailUrl,
      };
    }
    return null;
  }
}
