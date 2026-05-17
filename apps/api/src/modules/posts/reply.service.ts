import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService } from '../../shared/access-control.service';
import { RequestUser } from '../../shared/decorators/current-user.decorator';
import { PostAuthorDTO, ReplyDTO } from './dto/post.dto';

export interface CreateReplyInput {
  body: string;
  parent_reply_id?: string;
}

@Injectable()
export class ReplyService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
  ) {}

  async create(postId: string, input: CreateReplyInput, viewer: RequestUser): Promise<ReplyDTO> {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      include: { room: { include: { category: { include: { space: true } } } } },
    });
    if (!post || post.status === 'DELETED') {
      throw new NotFoundException(`Post not found: ${postId}`);
    }
    await this.access.assertCanReadRoomBySlug(post.room.slug, viewer);
    const spaceAccessPolicy = post.room.category?.space?.accessPolicy ?? 'PUBLIC';

    // Depth check: parent_reply_id may only reference a top-level reply.
    let parent: { id: string; postId: string; parentReplyId: string | null; status: string; authorId: string } | null = null;
    if (input.parent_reply_id) {
      parent = await this.prisma.reply.findUnique({
        where: { id: input.parent_reply_id },
        select: { id: true, postId: true, parentReplyId: true, status: true, authorId: true },
      });
      if (!parent || parent.status === 'DELETED') {
        throw new NotFoundException('parent_reply_id not found');
      }
      if (parent.postId !== postId) {
        throw new BadRequestException('parent_reply_id belongs to a different post');
      }
      if (parent.parentReplyId !== null) {
        throw new BadRequestException('Replies cannot be nested deeper than 2 levels');
      }
    }

    const viewerNickname = (viewer as any).profile?.nickname ?? viewer.id.slice(0, 8);
    const bodyPreview = input.body.slice(0, 80);

    const created = await this.prisma.$transaction(async (tx) => {
      const reply = await tx.reply.create({
        data: {
          postId,
          parentReplyId: input.parent_reply_id ?? null,
          authorId: viewer.id,
          body: input.body,
        },
        include: { author: { include: { profile: true } } },
      });
      await tx.post.update({
        where: { id: postId },
        data: { replyCount: { increment: 1 } },
      });

      // Emit notifications (never notify self)
      const notifs: Array<{ userId: string; type: string; payload: object }> = [];
      if (post.authorId !== viewer.id) {
        notifs.push({
          userId: post.authorId,
          type: 'REPLY_ON_POST',
          payload: {
            postId, replyId: reply.id,
            roomSlug: post.room.slug, roomName: post.room.name,
            spaceAccessPolicy, authorNickname: viewerNickname, bodyPreview,
          },
        });
      }
      if (parent && parent.authorId !== viewer.id && parent.authorId !== post.authorId) {
        notifs.push({
          userId: parent.authorId,
          type: 'NESTED_REPLY',
          payload: {
            postId, replyId: reply.id, parentReplyId: parent.id,
            roomSlug: post.room.slug, roomName: post.room.name,
            spaceAccessPolicy, authorNickname: viewerNickname, bodyPreview,
          },
        });
      }
      if (notifs.length > 0) {
        await tx.notification.createMany({ data: notifs });
      }

      return reply;
    });

    return this.toDTO(created, viewer.id);
  }

  async listByPost(postId: string, viewer: RequestUser): Promise<ReplyDTO[]> {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      include: { room: true },
    });
    if (!post || post.status === 'DELETED') {
      throw new NotFoundException(`Post not found: ${postId}`);
    }
    await this.access.assertCanReadRoomBySlug(post.room.slug, viewer);

    const replies = await this.prisma.reply.findMany({
      where: { postId, status: { notIn: ['DELETED', 'HIDDEN'] } },
      include: { author: { include: { profile: true } } },
      orderBy: [{ createdAt: 'asc' }],
    });

    // Resolve liked-by-me in a single query
    const likedReplyIds = await this.prisma.reaction.findMany({
      where: {
        userId: viewer.id,
        targetType: 'REPLY',
        targetId: { in: replies.map((r) => r.id) },
        reactionType: 'LIKE',
      },
      select: { targetId: true },
    });
    const likedSet = new Set(likedReplyIds.map((r) => r.targetId));

    return replies.map((r) => this.toDTO(r, viewer.id, likedSet.has(r.id)));
  }

  async softDelete(replyId: string, viewer: RequestUser): Promise<void> {
    const reply = await this.prisma.reply.findUnique({
      where: { id: replyId },
      include: { post: { include: { room: true } } },
    });
    if (!reply || reply.status === 'DELETED') {
      throw new NotFoundException(`Reply not found: ${replyId}`);
    }
    await this.access.assertCanReadRoomBySlug(reply.post.room.slug, viewer);
    if (reply.authorId !== viewer.id) {
      throw new ForbiddenException('Only the author can delete this reply');
    }
    await this.prisma.$transaction(async (tx) => {
      await tx.reply.update({ where: { id: replyId }, data: { status: 'DELETED' } });
      await tx.post.update({
        where: { id: reply.postId },
        data: { replyCount: { decrement: 1 } },
      });
    });
  }

  private toDTO(
    reply: {
      id: string;
      postId: string;
      parentReplyId: string | null;
      body: string;
      status: string;
      likeCount: number;
      createdAt: Date;
      updatedAt: Date;
      author: { id: string; profile: { nickname: string; avatarUrl: string | null } | null } | null;
    },
    _viewerId: string,
    likedByMe: boolean = false,
  ): ReplyDTO {
    const author: PostAuthorDTO = {
      id: reply.author?.id ?? '',
      nickname: reply.author?.profile?.nickname ?? '',
      avatar_url: reply.author?.profile?.avatarUrl ?? null,
    };
    return {
      id: reply.id,
      post_id: reply.postId,
      parent_reply_id: reply.parentReplyId,
      author,
      body: reply.body,
      status: reply.status,
      created_at: reply.createdAt.toISOString(),
      updated_at: reply.updatedAt.toISOString(),
      like_count: reply.likeCount,
      liked_by_me: likedByMe,
    };
  }
}
