import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService } from '../../shared/access-control.service';
import { RequestUser } from '../../shared/decorators/current-user.decorator';
import { AnalyticsService } from '../analytics/analytics.service';
import {
  BlockMuteService,
  assertNotBlocked,
} from '../../shared/block-mute.service';
import { MentionService } from '../notifications/mention.service';
import { NotificationService } from '../notifications/notification.service';
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
    private readonly analytics: AnalyticsService,
    private readonly mentions: MentionService,
    private readonly blockMute: BlockMuteService,
    private readonly notifications: NotificationService,
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
    // P6.2: block check vs post author. Replying to someone we're
    // blocked-either-way with is rejected with a friendly conflict
    // (not 403 — the reader is allowed to read the post, just not
    // engage with the author).
    if (post.authorId !== viewer.id) {
      await assertNotBlocked(this.blockMute, viewer.id, post.authorId);
    }
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
      return reply;
    });

    // P6.3: notification fan-out runs POST-transaction so the grouping
    // upsert (read existing → conditional INSERT/UPDATE) doesn't pin a
    // transaction open longer than needed. Notification write failures
    // never block the reply itself — the underlying tx already
    // committed.
    if (post.authorId !== viewer.id) {
      await this.notifications.createOrGroup({
        userId: post.authorId,
        type: 'REPLY_ON_POST',
        actorId: viewer.id,
        groupKey: `REPLY_ON_POST:${postId}`,
        payload: {
          postId,
          replyId: created.id,
          roomSlug: post.room.slug,
          roomName: post.room.name,
          spaceAccessPolicy,
          authorNickname: viewerNickname,
          bodyPreview,
        },
      });
    }
    if (parent && parent.authorId !== viewer.id && parent.authorId !== post.authorId) {
      await this.notifications.createOrGroup({
        userId: parent.authorId,
        type: 'NESTED_REPLY',
        actorId: viewer.id,
        groupKey: `NESTED_REPLY:${parent.id}`,
        payload: {
          postId,
          replyId: created.id,
          parentReplyId: parent.id,
          roomSlug: post.room.slug,
          roomName: post.room.name,
          spaceAccessPolicy,
          authorNickname: viewerNickname,
          bodyPreview,
        },
      });
    }

    this.analytics.record({
      actorId: viewer.id,
      eventType: 'REPLY_CREATED',
      payload: {
        reply_id: created.id,
        post_id: postId,
        is_nested: input.parent_reply_id ? true : false,
      },
    });

    // P6.1: mention fanout — fire-and-forget. Deep-link payload sends
    // the recipient back to the source post (replies live inside it).
    void this.mentions.recordMentions({
      sourceType: 'REPLY',
      sourceId: created.id,
      authorId: viewer.id,
      body: input.body,
      spaceAccessPolicy,
      notificationPayloadExtras: {
        postId,
        replyId: created.id,
        roomSlug: post.room.slug,
      },
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
    // P6.1: drop mention rows on hard delete.
    await this.mentions.clearForSource('REPLY', replyId);
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
