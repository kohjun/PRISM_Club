import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService } from '../../shared/access-control.service';
import { RequestUser } from '../../shared/decorators/current-user.decorator';

export type ReactionTargetType = 'POST' | 'REPLY';

/**
 * P6.4 reaction palette. Six entries chosen so the picker fits one
 * row at 360dp; matches the Korean copy in
 * `apps/mobile/lib/widgets/reaction_palette.dart`. Adding a new
 * reaction REQUIRES updating that mobile constant in lockstep.
 */
export const REACTION_TYPES = [
  'HEART',
  'THUMBS_UP',
  'FIRE',
  'THINK',
  'IDEA',
  'LAUGH',
] as const;
export type ReactionType = (typeof REACTION_TYPES)[number];

function isReactionType(v: unknown): v is ReactionType {
  return (
    typeof v === 'string' && (REACTION_TYPES as readonly string[]).includes(v)
  );
}

export interface ReactionSummary {
  my_reaction: ReactionType | null;
  reaction_counts: Record<ReactionType, number>;
  /** Aggregate of all reactions (used by M7 trending ordering). */
  like_count: number;
}

@Injectable()
export class ReactionService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
  ) {}

  /**
   * P6.4 toggle. A user holds at most one reaction per target;
   * calling with the same `reactionType` removes the existing row
   * ("undo"), calling with a different type swaps it in place
   * ("change emoji"), and a fresh target creates a new row.
   *
   * The aggregate `like_count` on Post / Reply continues to mean
   * "total reactions across all types" so the M7 trending ordering
   * keeps working unchanged.
   */
  async toggle(
    viewer: RequestUser,
    targetType: ReactionTargetType,
    targetId: string,
    reactionType: ReactionType,
  ): Promise<ReactionSummary> {
    if (!isReactionType(reactionType)) {
      throw new BadRequestException(
        `Unsupported reaction_type: ${String(reactionType)}`,
      );
    }
    await this.ensureTargetAccess(viewer, targetType, targetId);

    await this.prisma.$transaction(async (tx) => {
      const existing = await tx.reaction.findUnique({
        where: {
          userId_targetType_targetId: {
            userId: viewer.id,
            targetType,
            targetId,
          },
        },
      });

      if (!existing) {
        await tx.reaction.create({
          data: {
            userId: viewer.id,
            targetType,
            targetId,
            reactionType,
          },
        });
        await this.incrementCounter(tx, targetType, targetId);
        return;
      }

      if (existing.reactionType === reactionType) {
        // Undo.
        await tx.reaction.delete({ where: { id: existing.id } });
        await this.decrementCounter(tx, targetType, targetId);
        return;
      }

      // Swap reaction type — aggregate count stays the same.
      await tx.reaction.update({
        where: { id: existing.id },
        data: { reactionType },
      });
    });

    return this.summarize(viewer.id, targetType, targetId);
  }

  /**
   * Back-compat shim. Old `/v1/reactions/toggle` callers (mobile prior
   * to the palette UI) land on HEART so existing engagement stays
   * intact while the mobile rollout catches up.
   */
  async toggleLike(
    viewer: RequestUser,
    targetType: ReactionTargetType,
    targetId: string,
  ): Promise<{ liked: boolean; like_count: number }> {
    const summary = await this.toggle(viewer, targetType, targetId, 'HEART');
    return {
      liked: summary.my_reaction === 'HEART',
      like_count: summary.like_count,
    };
  }

  /**
   * Returns the per-target reaction summary. Used by toggle() to
   * compute the response payload.
   */
  async summarize(
    viewerId: string,
    targetType: ReactionTargetType,
    targetId: string,
  ): Promise<ReactionSummary> {
    const [groups, mine, target] = await Promise.all([
      this.prisma.reaction.groupBy({
        by: ['reactionType'],
        where: { targetType, targetId },
        _count: { _all: true },
      }),
      this.prisma.reaction.findUnique({
        where: {
          userId_targetType_targetId: {
            userId: viewerId,
            targetType,
            targetId,
          },
        },
        select: { reactionType: true },
      }),
      targetType === 'POST'
        ? this.prisma.post.findUnique({
            where: { id: targetId },
            select: { likeCount: true },
          })
        : this.prisma.reply.findUnique({
            where: { id: targetId },
            select: { likeCount: true },
          }),
    ]);

    const counts: Record<ReactionType, number> = {
      HEART: 0,
      THUMBS_UP: 0,
      FIRE: 0,
      THINK: 0,
      IDEA: 0,
      LAUGH: 0,
    };
    for (const g of groups) {
      if (isReactionType(g.reactionType)) {
        counts[g.reactionType] = g._count._all;
      }
    }
    return {
      my_reaction: isReactionType(mine?.reactionType)
        ? (mine!.reactionType as ReactionType)
        : null,
      reaction_counts: counts,
      like_count: target?.likeCount ?? 0,
    };
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

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private async incrementCounter(tx: any, targetType: ReactionTargetType, targetId: string): Promise<void> {
    if (targetType === 'POST') {
      await tx.post.update({
        where: { id: targetId },
        data: { likeCount: { increment: 1 } },
      });
      return;
    }
    await tx.reply.update({
      where: { id: targetId },
      data: { likeCount: { increment: 1 } },
    });
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private async decrementCounter(tx: any, targetType: ReactionTargetType, targetId: string): Promise<void> {
    if (targetType === 'POST') {
      await tx.post.update({
        where: { id: targetId },
        data: { likeCount: { decrement: 1 } },
      });
      return;
    }
    await tx.reply.update({
      where: { id: targetId },
      data: { likeCount: { decrement: 1 } },
    });
  }
}
