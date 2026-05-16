import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService } from '../../shared/access-control.service';
import { RequestUser } from '../../shared/decorators/current-user.decorator';

export type ReactionTargetType = 'POST' | 'REPLY';

@Injectable()
export class ReactionService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
  ) {}

  /**
   * Idempotent toggle. Returns the resulting state.
   *
   * The same row in `reactions` represents one user's like on one target.
   * UNIQUE(user_id, target_type, target_id, reaction_type) prevents duplicates.
   */
  async toggleLike(
    viewer: RequestUser,
    targetType: ReactionTargetType,
    targetId: string,
  ): Promise<{ liked: boolean; like_count: number }> {
    await this.ensureTargetAccess(viewer, targetType, targetId);

    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.reaction.findUnique({
        where: {
          userId_targetType_targetId_reactionType: {
            userId: viewer.id,
            targetType,
            targetId,
            reactionType: 'LIKE',
          },
        },
      });

      if (existing) {
        await tx.reaction.delete({ where: { id: existing.id } });
        const target = await this.decrementCounter(tx, targetType, targetId);
        return { liked: false, like_count: target.like_count };
      }

      await tx.reaction.create({
        data: { userId: viewer.id, targetType, targetId, reactionType: 'LIKE' },
      });
      const target = await this.incrementCounter(tx, targetType, targetId);
      return { liked: true, like_count: target.like_count };
    });
  }

  private async ensureTargetAccess(
    viewer: RequestUser,
    targetType: ReactionTargetType,
    targetId: string,
  ): Promise<void> {
    if (targetType === 'POST') {
      const p = await this.prisma.post.findUnique({
        where: { id: targetId },
        select: { id: true, status: true, room: { select: { slug: true } } },
      });
      if (!p || p.status === 'DELETED') throw new NotFoundException(`Post not found: ${targetId}`);
      await this.access.assertCanReadRoomBySlug(p.room.slug, viewer);
    } else if (targetType === 'REPLY') {
      const r = await this.prisma.reply.findUnique({
        where: { id: targetId },
        select: { id: true, status: true, post: { select: { room: { select: { slug: true } } } } },
      });
      if (!r || r.status === 'DELETED') throw new NotFoundException(`Reply not found: ${targetId}`);
      await this.access.assertCanReadRoomBySlug(r.post.room.slug, viewer);
    } else {
      throw new BadRequestException(`Unsupported target_type: ${String(targetType)}`);
    }
  }

  private async incrementCounter(tx: any, targetType: ReactionTargetType, targetId: string): Promise<{ like_count: number }> {
    if (targetType === 'POST') {
      const updated = await tx.post.update({
        where: { id: targetId },
        data: { likeCount: { increment: 1 } },
        select: { likeCount: true },
      });
      return { like_count: updated.likeCount };
    }
    const updated = await tx.reply.update({
      where: { id: targetId },
      data: { likeCount: { increment: 1 } },
      select: { likeCount: true },
    });
    return { like_count: updated.likeCount };
  }

  private async decrementCounter(tx: any, targetType: ReactionTargetType, targetId: string): Promise<{ like_count: number }> {
    if (targetType === 'POST') {
      const updated = await tx.post.update({
        where: { id: targetId },
        data: { likeCount: { decrement: 1 } },
        select: { likeCount: true },
      });
      return { like_count: Math.max(0, updated.likeCount) };
    }
    const updated = await tx.reply.update({
      where: { id: targetId },
      data: { likeCount: { decrement: 1 } },
      select: { likeCount: true },
    });
    return { like_count: Math.max(0, updated.likeCount) };
  }
}
