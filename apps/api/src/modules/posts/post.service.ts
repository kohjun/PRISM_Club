import {
  BadRequestException,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService } from '../../shared/access-control.service';
import { RequestUser } from '../../shared/decorators/current-user.decorator';
import { RateLimitService } from '../../shared/rate-limit.service';
import { RoomService } from '../community/room.service';
import { AnalyticsService } from '../analytics/analytics.service';
import { AutoModerationService } from '../moderation/auto-moderation.service';
import {
  PostAttachmentDTO,
  PostAuthorDTO,
  PostDTO,
  PostType,
  QuotedPostRefDTO,
  RecruitmentFieldsDTO,
  RecruitmentStatus,
} from './dto/post.dto';

export interface AttachmentInput {
  attachment_type: 'EVENT_CARD' | 'REFERENCE' | 'IMAGE';
  target_id: string;
}

export interface RecruitmentFieldsInput {
  role: string;
  schedule: string;
  location: string;
  compensation: string;
  capacity: number;
  application_method: string;
  status?: RecruitmentStatus;
}

export interface CreatePostInput {
  body: string;
  post_type?: PostType;
  recruitment_fields?: RecruitmentFieldsInput;
  attachments?: AttachmentInput[];
  /** P4.2: optional quoted post; access-checked at create time. */
  quoted_post_id?: string | null;
}

export interface TimelinePage {
  items: PostDTO[];
  next_cursor: string | null;
}

const DEFAULT_PAGE_SIZE = 20;
const MAX_PAGE_SIZE = 50;

@Injectable()
export class PostService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
    private readonly rooms: RoomService,
    private readonly analytics: AnalyticsService,
    private readonly rateLimit: RateLimitService,
    private readonly autoMod: AutoModerationService,
  ) {}

  async create(roomSlug: string, input: CreatePostInput, viewer: RequestUser): Promise<PostDTO> {
    // P5.1: tier-aware rate limit. Shadow mode (default) records the
    // hit but lets the request through; enforce mode (RATE_LIMIT_ENABLED=1)
    // returns 429 with Retry-After.
    const decision = this.rateLimit.consume({
      scope: 'post.create',
      viewer,
    });
    if (!decision.allowed) {
      throw new HttpException(
        {
          error: {
            code: 'RATE_LIMITED',
            message: '잠시 후 다시 시도해주세요.',
            retry_after_seconds: Math.ceil(decision.ttl_ms / 1000),
          },
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    await this.access.assertCanReadRoomBySlug(roomSlug, viewer);
    const room = await this.rooms.getRoomBySlug(roomSlug);
    await this.validateAttachmentTargets(input.attachments ?? []);

    const postType: PostType = input.post_type ?? 'GENERAL';
    let recruitmentFields: RecruitmentFieldsInput | null = null;

    if (postType === 'RECRUITMENT') {
      if (room.roomType !== 'RECRUITMENT') {
        throw new BadRequestException(
          'Recruitment posts can only be created in RECRUITMENT rooms',
        );
      }
      if (!input.recruitment_fields) {
        throw new BadRequestException(
          'recruitment_fields is required when post_type=RECRUITMENT',
        );
      }
      recruitmentFields = {
        ...input.recruitment_fields,
        status: input.recruitment_fields.status ?? 'OPEN',
      };
    } else if (input.recruitment_fields) {
      throw new BadRequestException(
        'recruitment_fields is only allowed when post_type=RECRUITMENT',
      );
    }

    // P4.2: validate the quoted post (if any) before opening the tx.
    let quotedPostId: string | null = null;
    if (input.quoted_post_id) {
      const quoted = await this.prisma.post.findUnique({
        where: { id: input.quoted_post_id },
        include: {
          room: { include: { category: { include: { space: true } } } },
        },
      });
      if (
        !quoted ||
        quoted.status === 'DELETED' ||
        quoted.status === 'HIDDEN'
      ) {
        throw new NotFoundException(
          `Quoted post not found: ${input.quoted_post_id}`,
        );
      }
      if (
        !this.access
          .accessPoliciesAllowedFor(viewer)
          .includes(quoted.room.category.space.accessPolicy)
      ) {
        throw new NotFoundException(
          `Quoted post not found: ${input.quoted_post_id}`,
        );
      }
      quotedPostId = quoted.id;
    }

    // P5.2 auto-moderation evaluation (NEW/MEMBER only, shadow mode
    // unless AUTO_MODERATION_ENFORCE=1). When triggered, the post is
    // still persisted but with status=HIDDEN + auto_moderation_reason
    // so the author sees a banner and the admin queue can review.
    const autoModDecision = await this.autoMod.evaluatePostBeforeCreate({
      viewer,
      body: input.body,
    });

    const post = await this.prisma.$transaction(async (tx) => {
      const created = await tx.post.create({
        data: {
          roomId: room.id,
          authorId: viewer.id,
          body: input.body,
          postType,
          status: autoModDecision.hide ? 'HIDDEN' : 'VISIBLE',
          autoModeratedAt: autoModDecision.hide ? new Date() : null,
          autoModerationReason: autoModDecision.reason,
          recruitmentFields:
            recruitmentFields === null
              ? Prisma.JsonNull
              : (recruitmentFields as unknown as Prisma.InputJsonValue),
          attachments:
            input.attachments && input.attachments.length > 0
              ? {
                  create: input.attachments.map((a, idx) => ({
                    attachmentType: a.attachment_type,
                    targetId: a.target_id,
                    sortOrder: idx + 1,
                  })),
                }
              : undefined,
        },
      });
      // P3.6: also write the structured RecruitmentPost row so the
      // application-tracking surface has a 1:1 anchor to query. The
      // legacy `recruitmentFields` JSON is still written for
      // backward-compat with mobile reads — dual-write window until
      // those readers move to the new shape.
      if (postType === 'RECRUITMENT' && recruitmentFields !== null) {
        await tx.recruitmentPost.create({
          data: {
            postId: created.id,
            capacity: recruitmentFields.capacity ?? null,
            status: recruitmentFields.status ?? 'OPEN',
            // deadline_at is not on the existing RecruitmentFieldsInput
            // shape today — the structured row keeps it nullable so a
            // future composer that surfaces a deadline picker can fill
            // it in without a schema migration.
          },
        });
      }
      // P4.2: persist the quote relationship. The unique constraint on
      // quoting_post_id means a post can quote at most one other.
      if (quotedPostId !== null) {
        await tx.postQuote.create({
          data: {
            quotingPostId: created.id,
            quotedPostId,
          },
        });
      }
      return created;
    });

    // Notify room followers of new post (post-tx, non-blocking)
    const followers = await this.prisma.roomFollow.findMany({ where: { roomId: room.id } });
    if (followers.length > 0) {
      const spaceRow = await this.prisma.room.findUnique({
        where: { id: room.id },
        include: { category: { include: { space: true } } },
      });
      const spaceAccessPolicy = spaceRow?.category?.space?.accessPolicy ?? 'PUBLIC';
      const bodyPreview = input.body.slice(0, 80);
      const notifs = followers
        .filter((f) => f.userId !== viewer.id)
        .map((f) => ({
          userId: f.userId,
          type: 'NEW_POST_IN_FOLLOWED_ROOM',
          payload: {
            postId: post.id, roomSlug: room.slug, roomName: room.name,
            spaceAccessPolicy, bodyPreview,
          },
        }));
      if (notifs.length > 0) {
        await this.prisma.notification.createMany({ data: notifs });
      }
    }

    this.analytics.record({
      actorId: viewer.id,
      eventType: 'POST_CREATED',
      payload: {
        post_id: post.id,
        room_slug: room.slug,
        post_type: postType,
        attachment_count: input.attachments?.length ?? 0,
      },
    });

    return this.getById(post.id, viewer);
  }

  async setRecruitmentStatus(
    postId: string,
    status: RecruitmentStatus,
    viewer: RequestUser,
  ): Promise<PostDTO> {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      include: { room: true },
    });
    if (!post || post.status === 'DELETED') {
      throw new NotFoundException(`Post not found: ${postId}`);
    }
    await this.access.assertCanReadRoomBySlug(post.room.slug, viewer);
    if (post.postType !== 'RECRUITMENT') {
      throw new BadRequestException('Not a recruitment post');
    }
    if (post.authorId !== viewer.id && !viewer.roles.includes('ADMIN')) {
      throw new ForbiddenException('Only the author can change recruitment status');
    }

    const current = (post.recruitmentFields as Record<string, unknown> | null) ?? {};
    const next = { ...current, status };

    await this.prisma.post.update({
      where: { id: postId },
      data: { recruitmentFields: next as unknown as Prisma.InputJsonValue },
    });

    // Notify room followers of status change (non-blocking)
    const followers = await this.prisma.roomFollow.findMany({ where: { roomId: post.roomId } });
    if (followers.length > 0) {
      const spaceRow = await this.prisma.room.findUnique({
        where: { id: post.roomId },
        include: { category: { include: { space: true } } },
      });
      const spaceAccessPolicy = spaceRow?.category?.space?.accessPolicy ?? 'PUBLIC';
      const role = ((post.recruitmentFields as Record<string, unknown> | null)?.role as string) ?? '';
      const notifs = followers
        .filter((f) => f.userId !== viewer.id)
        .map((f) => ({
          userId: f.userId,
          type: 'RECRUITMENT_STATUS_CHANGED',
          payload: {
            postId, roomSlug: post.room.slug, roomName: post.room.name,
            spaceAccessPolicy, status, role,
          },
        }));
      if (notifs.length > 0) {
        await this.prisma.notification.createMany({ data: notifs });
      }
    }

    return this.getById(postId, viewer);
  }

  async getById(postId: string, viewer: RequestUser): Promise<PostDTO> {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      include: {
        room: true,
        author: { include: { profile: true } },
        attachments: { orderBy: { sortOrder: 'asc' } },
      },
    });
    if (!post || post.status === 'DELETED') {
      throw new NotFoundException(`Post not found: ${postId}`);
    }
    await this.access.assertCanReadRoomBySlug(post.room.slug, viewer);
    return this.toDTO(post, viewer.id);
  }

  async listByRoomSlug(
    roomSlug: string,
    viewer: RequestUser,
    cursor?: string,
    limit?: number,
  ): Promise<TimelinePage> {
    await this.access.assertCanReadRoomBySlug(roomSlug, viewer);
    const room = await this.rooms.getRoomBySlug(roomSlug);
    const take = Math.max(1, Math.min(limit ?? DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE));

    const posts = await this.prisma.post.findMany({
      where: { roomId: room.id, status: { notIn: ['DELETED', 'HIDDEN'] } },
      include: {
        room: true,
        author: { include: { profile: true } },
        attachments: { orderBy: { sortOrder: 'asc' } },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: take + 1,
      ...(cursor
        ? {
            cursor: { id: cursor },
            skip: 1,
          }
        : {}),
    });

    const hasMore = posts.length > take;
    const sliced = hasMore ? posts.slice(0, take) : posts;
    const items = await Promise.all(sliced.map((p) => this.toDTO(p, viewer.id)));

    return {
      items,
      next_cursor: hasMore ? sliced[sliced.length - 1].id : null,
    };
  }

  async update(postId: string, body: string, viewer: RequestUser): Promise<PostDTO> {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      include: { room: true },
    });
    if (!post || post.status === 'DELETED') {
      throw new NotFoundException(`Post not found: ${postId}`);
    }
    await this.access.assertCanReadRoomBySlug(post.room.slug, viewer);
    if (post.authorId !== viewer.id) {
      throw new ForbiddenException('Only the author can edit this post');
    }
    await this.prisma.post.update({ where: { id: postId }, data: { body } });
    return this.getById(postId, viewer);
  }

  async softDelete(postId: string, viewer: RequestUser): Promise<void> {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      include: { room: true },
    });
    if (!post || post.status === 'DELETED') {
      throw new NotFoundException(`Post not found: ${postId}`);
    }
    await this.access.assertCanReadRoomBySlug(post.room.slug, viewer);
    if (post.authorId !== viewer.id) {
      throw new ForbiddenException('Only the author can delete this post');
    }
    await this.prisma.post.update({ where: { id: postId }, data: { status: 'DELETED' } });
  }

  // -- helpers -------------------------------------------------------------

  private async validateAttachmentTargets(attachments: AttachmentInput[]): Promise<void> {
    if (attachments.length === 0) return;
    if (attachments.length > 10) {
      throw new BadRequestException('Up to 10 attachments per post');
    }

    const eventIds = attachments
      .filter((a) => a.attachment_type === 'EVENT_CARD')
      .map((a) => a.target_id);
    const refIds = attachments
      .filter((a) => a.attachment_type === 'REFERENCE')
      .map((a) => a.target_id);
    const mediaIds = attachments
      .filter((a) => a.attachment_type === 'IMAGE')
      .map((a) => a.target_id);

    const [eventCount, refCount, mediaCount] = await Promise.all([
      eventIds.length > 0
        ? this.prisma.eventCard.count({ where: { id: { in: eventIds } } })
        : Promise.resolve(0),
      refIds.length > 0
        ? this.prisma.reference.count({ where: { id: { in: refIds } } })
        : Promise.resolve(0),
      mediaIds.length > 0
        ? this.prisma.mediaAsset.count({ where: { id: { in: mediaIds } } })
        : Promise.resolve(0),
    ]);

    if (
      eventCount !== eventIds.length ||
      refCount !== refIds.length ||
      mediaCount !== mediaIds.length
    ) {
      throw new NotFoundException('One or more attachment targets not found');
    }
  }

  /**
   * Public batch helper for converting Prisma post rows into DTOs.
   * Reused by EventDetailService (M5) so the related-posts payload uses
   * the same shape as the room timeline.
   */
  async postsToDTOs(
    rows: Prisma.PostGetPayload<{
      include: { room: true; author: { include: { profile: true } }; attachments: true };
    }>[],
    viewerId: string,
  ): Promise<PostDTO[]> {
    const quoteMap = await this.fetchQuoteRefs(rows.map((r) => r.id));
    return Promise.all(
      rows.map((p) => this.toDTO(p, viewerId, quoteMap.get(p.id) ?? null)),
    );
  }

  private async toDTO(
    post: Prisma.PostGetPayload<{
      include: { room: true; author: { include: { profile: true } }; attachments: true };
    }>,
    viewerId: string,
    quotedPost?: QuotedPostRefDTO | null,
  ): Promise<PostDTO> {
    const attachments = await this.resolveAttachments(post.attachments);
    const likedByMe = await this.isLikedBy(viewerId, 'POST', post.id);
    const quote =
      quotedPost === undefined
        ? (await this.fetchQuoteRefs([post.id])).get(post.id) ?? null
        : quotedPost;

    return {
      id: post.id,
      room: { id: post.room.id, slug: post.room.slug, name: post.room.name },
      author: this.toAuthor(post.author),
      body: post.body,
      status: post.status,
      post_type: (post.postType as PostType) ?? 'GENERAL',
      recruitment_fields: this.toRecruitmentFieldsDTO(post.recruitmentFields),
      created_at: post.createdAt.toISOString(),
      updated_at: post.updatedAt.toISOString(),
      attachments,
      counts: { reply_count: post.replyCount, like_count: post.likeCount },
      liked_by_me: likedByMe,
      quoted_post: quote,
    };
  }

  /**
   * Batch-resolve PostQuote rows for a set of quoting posts in one query
   * so the timeline serializer stays O(rows) instead of O(rows²). Each
   * value is the quoted-post reference or a sentinel "deleted" reference
   * when the original was nulled out via FK SET NULL.
   */
  private async fetchQuoteRefs(
    quotingPostIds: string[],
  ): Promise<Map<string, QuotedPostRefDTO | null>> {
    if (quotingPostIds.length === 0) return new Map();
    const quotes = await this.prisma.postQuote.findMany({
      where: { quotingPostId: { in: quotingPostIds } },
      include: {
        quotedPost: {
          include: {
            room: true,
            author: { include: { profile: true } },
          },
        },
      },
    });
    const out = new Map<string, QuotedPostRefDTO | null>();
    for (const q of quotes) {
      if (!q.quotedPost) {
        out.set(q.quotingPostId, {
          id: '',
          body_preview: '(삭제된 글)',
          author_nickname: '',
          room_slug: '',
          available: false,
        });
        continue;
      }
      out.set(q.quotingPostId, {
        id: q.quotedPost.id,
        body_preview: q.quotedPost.body.slice(0, 140),
        author_nickname: q.quotedPost.author.profile?.nickname ?? '',
        room_slug: q.quotedPost.room.slug,
        available: q.quotedPost.status !== 'DELETED' && q.quotedPost.status !== 'HIDDEN',
      });
    }
    return out;
  }

  private toRecruitmentFieldsDTO(raw: Prisma.JsonValue | null): RecruitmentFieldsDTO | null {
    if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) return null;
    const r = raw as Record<string, unknown>;
    if (typeof r.role !== 'string') return null;
    return {
      role: r.role,
      schedule: String(r.schedule ?? ''),
      location: String(r.location ?? ''),
      compensation: String(r.compensation ?? ''),
      capacity: typeof r.capacity === 'number' ? r.capacity : Number(r.capacity ?? 0),
      application_method: String(r.application_method ?? ''),
      status:
        r.status === 'CLOSED' || r.status === 'FILLED'
          ? (r.status as RecruitmentStatus)
          : 'OPEN',
    };
  }

  private toAuthor(user: { id: string; profile: { nickname: string; avatarUrl: string | null } | null }): PostAuthorDTO {
    return {
      id: user.id,
      nickname: user.profile?.nickname ?? '',
      avatar_url: user.profile?.avatarUrl ?? null,
    };
  }

  private async resolveAttachments(
    attachmentRows: Array<{ id: string; attachmentType: string; targetId: string; sortOrder: number }>,
  ): Promise<PostAttachmentDTO[]> {
    if (attachmentRows.length === 0) return [];

    const eventIds = attachmentRows
      .filter((a) => a.attachmentType === 'EVENT_CARD')
      .map((a) => a.targetId);
    const refIds = attachmentRows
      .filter((a) => a.attachmentType === 'REFERENCE')
      .map((a) => a.targetId);
    const mediaIds = attachmentRows
      .filter((a) => a.attachmentType === 'IMAGE')
      .map((a) => a.targetId);

    const [events, references, mediaAssets] = await Promise.all([
      eventIds.length > 0
        ? this.prisma.eventCard.findMany({ where: { id: { in: eventIds } } })
        : Promise.resolve([]),
      refIds.length > 0
        ? this.prisma.reference.findMany({ where: { id: { in: refIds } } })
        : Promise.resolve([]),
      mediaIds.length > 0
        ? this.prisma.mediaAsset.findMany({ where: { id: { in: mediaIds } } })
        : Promise.resolve([]),
    ]);

    const eMap = new Map(events.map((e) => [e.id, e]));
    const rMap = new Map(references.map((r) => [r.id, r]));
    const mMap = new Map(mediaAssets.map((m) => [m.id, m]));

    return attachmentRows
      .map((a): PostAttachmentDTO | null => {
        if (a.attachmentType === 'EVENT_CARD') {
          const e = eMap.get(a.targetId);
          if (!e) return null;
          return {
            id: a.id,
            attachment_type: 'EVENT_CARD',
            sort_order: a.sortOrder,
            target: this.rooms.toEventCardDTO(e),
          };
        }
        if (a.attachmentType === 'REFERENCE') {
          const r = rMap.get(a.targetId);
          if (!r) return null;
          return {
            id: a.id,
            attachment_type: 'REFERENCE',
            sort_order: a.sortOrder,
            target: this.rooms.toReferenceDTO(r),
          };
        }
        if (a.attachmentType === 'IMAGE') {
          const m = mMap.get(a.targetId);
          if (!m) return null;
          return {
            id: a.id,
            attachment_type: 'IMAGE',
            sort_order: a.sortOrder,
            target: {
              id: m.id,
              kind: 'IMAGE',
              filename: m.filename,
              mime_type: m.mimeType,
              size_bytes: m.sizeBytes,
              url: m.path,
              created_at: m.createdAt.toISOString(),
            },
          };
        }
        return null;
      })
      .filter((a): a is PostAttachmentDTO => a !== null)
      .sort((a, b) => a.sort_order - b.sort_order);
  }

  private async isLikedBy(userId: string, targetType: 'POST' | 'REPLY', targetId: string): Promise<boolean> {
    const r = await this.prisma.reaction.findFirst({
      where: { userId, targetType, targetId, reactionType: 'LIKE' },
      select: { id: true },
    });
    return r !== null;
  }
}
