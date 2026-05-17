import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService, Viewer } from '../../shared/access-control.service';
import { RoomService } from '../community/room.service';
import { PostService } from '../posts/post.service';
import {
  EventDetailBundleDTO,
  RelatedRoomDTO,
} from './dto/event-detail.dto';

const DEFAULT_POSTS_LIMIT = 20;
const MAX_POSTS_LIMIT = 50;
const DEFAULT_ROOMS_LIMIT = 10;
const MAX_ROOMS_LIMIT = 50;

export interface GetBundleOpts {
  postsLimit?: number;
  postsCursor?: string;
  roomsLimit?: number;
}

const postInclude = {
  room: true,
  author: { include: { profile: true } },
  attachments: { orderBy: { sortOrder: 'asc' as const } },
};

@Injectable()
export class EventDetailService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
    private readonly rooms: RoomService,
    private readonly posts: PostService,
  ) {}

  async getBundle(
    cardId: string,
    viewer: Viewer & { id: string },
    opts: GetBundleOpts = {},
  ): Promise<EventDetailBundleDTO> {
    const card = await this.prisma.eventCard.findUnique({ where: { id: cardId } });
    if (!card) {
      throw new NotFoundException(`EventCard not found: ${cardId}`);
    }

    const allowed = this.access.accessPoliciesAllowedFor(viewer);
    const postsLimit = clamp(opts.postsLimit ?? DEFAULT_POSTS_LIMIT, 1, MAX_POSTS_LIMIT);
    const roomsLimit = clamp(opts.roomsLimit ?? DEFAULT_ROOMS_LIMIT, 1, MAX_ROOMS_LIMIT);

    // -- related posts (paged) --------------------------------------------
    const postRows = await this.prisma.post.findMany({
      where: this._relatedPostsWhere(cardId, allowed),
      include: postInclude,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: postsLimit + 1,
      ...(opts.postsCursor
        ? { cursor: { id: opts.postsCursor }, skip: 1 }
        : {}),
    });
    const hasMore = postRows.length > postsLimit;
    const slicedPosts = hasMore ? postRows.slice(0, postsLimit) : postRows;
    const postItems = await this.posts.postsToDTOs(slicedPosts, viewer.id);

    // -- counts -----------------------------------------------------------
    const postCount = await this.prisma.post.count({
      where: this._relatedPostsWhere(cardId, allowed),
    });

    // -- related rooms (PIN union POST_ATTACHMENT) -----------------------
    const pinRows = await this.prisma.roomPin.findMany({
      where: {
        targetType: 'EVENT_CARD',
        targetId: cardId,
        room: {
          status: 'ACTIVE',
          category: { space: { accessPolicy: { in: allowed } } },
        },
      },
      include: {
        room: {
          include: { owner: { include: { profile: true } } },
        },
      },
      take: roomsLimit,
    });

    const attachmentRoomIds = new Set<string>();
    if (postCount > 0) {
      // Distinct rooms from posts that attach this event (within access).
      const distinctRoomRows = await this.prisma.post.findMany({
        where: this._relatedPostsWhere(cardId, allowed),
        select: { roomId: true },
        distinct: ['roomId'],
        take: roomsLimit,
      });
      for (const r of distinctRoomRows) attachmentRoomIds.add(r.roomId);
    }

    const pinRoomIds = new Set(pinRows.map((p) => p.roomId));
    const onlyAttachmentRoomIds = [...attachmentRoomIds].filter(
      (id) => !pinRoomIds.has(id),
    );

    const attachmentOnlyRooms =
      onlyAttachmentRoomIds.length > 0
        ? await this.prisma.room.findMany({
            where: {
              id: { in: onlyAttachmentRoomIds },
              status: 'ACTIVE',
            },
            include: { owner: { include: { profile: true } } },
          })
        : [];

    const relatedRooms: RelatedRoomDTO[] = [
      ...pinRows.map((p) => this._toRelatedRoom(p.room, 'PIN')),
      ...attachmentOnlyRooms.map((r) =>
        this._toRelatedRoom(r, 'POST_ATTACHMENT'),
      ),
    ].slice(0, roomsLimit);

    // -- default compose room --------------------------------------------
    const defaultComposeRoomSlug = await this._resolveDefaultComposeRoom(
      relatedRooms,
      cardId,
      allowed,
    );

    return {
      event_card: this.rooms.toEventCardDTO(card),
      related_rooms: relatedRooms,
      related_posts: {
        items: postItems,
        next_cursor: hasMore
          ? slicedPosts[slicedPosts.length - 1].id
          : null,
      },
      default_compose_room_slug: defaultComposeRoomSlug,
      verified_reviews: [],
      counts: {
        post_count: postCount,
        room_count: relatedRooms.length,
      },
    };
  }

  // -- helpers -----------------------------------------------------------

  private _relatedPostsWhere(
    cardId: string,
    allowed: string[],
  ): Prisma.PostWhereInput {
    return {
      status: { notIn: ['DELETED', 'HIDDEN'] },
      attachments: {
        some: { attachmentType: 'EVENT_CARD', targetId: cardId },
      },
      room: {
        category: { space: { accessPolicy: { in: allowed } } },
      },
    };
  }

  /**
   * §2 step 5 — pick a compose target:
   *   1) Prefer related_rooms entries that are OFFICIAL EVENT_REACTION or
   *      DISCUSSION (i.e., where a Club user would naturally post).
   *   2) Else the first related_room.
   *   3) Else fall through topic_hub_event_links: find OFFICIAL rooms in
   *      the parent topic hub's category whose accessPolicy is allowed.
   *   4) Else null — the CTA disables on the client.
   */
  private async _resolveDefaultComposeRoom(
    relatedRooms: RelatedRoomDTO[],
    cardId: string,
    allowed: string[],
  ): Promise<string | null> {
    const preferred = relatedRooms.find(
      (r) =>
        r.origin === 'OFFICIAL' &&
        (r.room_type === 'EVENT_REACTION' || r.room_type === 'DISCUSSION'),
    );
    if (preferred) return preferred.slug;
    if (relatedRooms.length > 0) return relatedRooms[0].slug;

    const link = await this.prisma.topicHubEventLink.findFirst({
      where: { eventCardId: cardId },
      include: {
        hub: {
          include: { category: { include: { space: true } } },
        },
      },
    });
    if (!link) return null;
    if (!allowed.includes(link.hub.category.space.accessPolicy)) {
      return null;
    }

    const fallback = await this.prisma.room.findFirst({
      where: {
        categoryId: link.hub.categoryId,
        status: 'ACTIVE',
        origin: 'OFFICIAL',
        roomType: { in: ['EVENT_REACTION', 'DISCUSSION'] },
        category: { space: { accessPolicy: { in: allowed } } },
      },
      orderBy: { roomType: 'asc' }, // EVENT_REACTION before DISCUSSION alphabetically
    });
    return fallback?.slug ?? null;
  }

  private _toRelatedRoom(
    room: {
      id: string;
      slug: string;
      name: string;
      origin: string;
      roomType: string;
      owner: { profile: { nickname: string } | null } | null;
    },
    relation: 'PIN' | 'POST_ATTACHMENT',
  ): RelatedRoomDTO {
    return {
      id: room.id,
      slug: room.slug,
      name: room.name,
      origin: room.origin,
      room_type: room.roomType,
      owner_nickname: room.owner?.profile?.nickname ?? null,
      relation,
    };
  }
}

function clamp(n: number, lo: number, hi: number): number {
  if (Number.isNaN(n)) throw new BadRequestException('limit must be a number');
  return Math.max(lo, Math.min(hi, Math.floor(n)));
}
