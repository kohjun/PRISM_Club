import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma.service';
import { RoomService } from '../community/room.service';
import { PostAttachmentDTO, PostDTO, PostAuthorDTO } from './dto/post.dto';

export interface AttachmentInput {
  attachment_type: 'EVENT_CARD' | 'REFERENCE';
  target_id: string;
}

export interface CreatePostInput {
  body: string;
  attachments?: AttachmentInput[];
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
    private readonly rooms: RoomService,
  ) {}

  async create(roomSlug: string, input: CreatePostInput, userId: string): Promise<PostDTO> {
    const room = await this.rooms.getRoomBySlug(roomSlug);
    await this.validateAttachmentTargets(input.attachments ?? []);

    const post = await this.prisma.$transaction(async (tx) => {
      return tx.post.create({
        data: {
          roomId: room.id,
          authorId: userId,
          body: input.body,
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
    });

    return this.getById(post.id, userId);
  }

  async getById(postId: string, viewerId: string): Promise<PostDTO> {
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
    return this.toDTO(post, viewerId);
  }

  async listByRoomSlug(roomSlug: string, viewerId: string, cursor?: string, limit?: number): Promise<TimelinePage> {
    const room = await this.rooms.getRoomBySlug(roomSlug);
    const take = Math.max(1, Math.min(limit ?? DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE));

    const posts = await this.prisma.post.findMany({
      where: { roomId: room.id, status: { not: 'DELETED' } },
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
    const items = await Promise.all(sliced.map((p) => this.toDTO(p, viewerId)));

    return {
      items,
      next_cursor: hasMore ? sliced[sliced.length - 1].id : null,
    };
  }

  async update(postId: string, body: string, userId: string): Promise<PostDTO> {
    const post = await this.prisma.post.findUnique({ where: { id: postId } });
    if (!post || post.status === 'DELETED') {
      throw new NotFoundException(`Post not found: ${postId}`);
    }
    if (post.authorId !== userId) {
      throw new ForbiddenException('Only the author can edit this post');
    }
    await this.prisma.post.update({ where: { id: postId }, data: { body } });
    return this.getById(postId, userId);
  }

  async softDelete(postId: string, userId: string): Promise<void> {
    const post = await this.prisma.post.findUnique({ where: { id: postId } });
    if (!post || post.status === 'DELETED') {
      throw new NotFoundException(`Post not found: ${postId}`);
    }
    if (post.authorId !== userId) {
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

    const [eventCount, refCount] = await Promise.all([
      eventIds.length > 0
        ? this.prisma.eventCard.count({ where: { id: { in: eventIds } } })
        : Promise.resolve(0),
      refIds.length > 0
        ? this.prisma.reference.count({ where: { id: { in: refIds } } })
        : Promise.resolve(0),
    ]);

    if (eventCount !== eventIds.length || refCount !== refIds.length) {
      throw new NotFoundException('One or more attachment targets not found');
    }
  }

  private async toDTO(
    post: Prisma.PostGetPayload<{
      include: { room: true; author: { include: { profile: true } }; attachments: true };
    }>,
    viewerId: string,
  ): Promise<PostDTO> {
    const attachments = await this.resolveAttachments(post.attachments);
    const likedByMe = await this.isLikedBy(viewerId, 'POST', post.id);

    return {
      id: post.id,
      room: { id: post.room.id, slug: post.room.slug, name: post.room.name },
      author: this.toAuthor(post.author),
      body: post.body,
      status: post.status,
      created_at: post.createdAt.toISOString(),
      updated_at: post.updatedAt.toISOString(),
      attachments,
      counts: { reply_count: post.replyCount, like_count: post.likeCount },
      liked_by_me: likedByMe,
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

    const [events, references] = await Promise.all([
      eventIds.length > 0
        ? this.prisma.eventCard.findMany({ where: { id: { in: eventIds } } })
        : Promise.resolve([]),
      refIds.length > 0
        ? this.prisma.reference.findMany({ where: { id: { in: refIds } } })
        : Promise.resolve([]),
    ]);

    const eMap = new Map(events.map((e) => [e.id, e]));
    const rMap = new Map(references.map((r) => [r.id, r]));

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
