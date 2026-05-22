import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService } from '../../shared/access-control.service';
import {
  BlockMuteService,
  assertNotBlocked,
} from '../../shared/block-mute.service';
import { AnalyticsService } from '../analytics/analytics.service';
import { RequestUser } from '../../shared/decorators/current-user.decorator';

export interface BoostState {
  boost_count: number;
  boosted_by_me: boolean;
}

/**
 * P6.6 boost service — toggle amplify, no body needed.
 *
 * A boost is a "share without comment" amplify (Twitter retweet
 * semantics). Distinct from PostQuote (P4.2) which requires a new
 * post body. A user holds at most one boost per post; calling toggle
 * a second time removes the boost.
 *
 * Access guard: the viewer must be able to read the source room.
 * PLANNER_ONLY content boosted by a viewer with access stays
 * invisible to non-planner followers — the home-feed serializer
 * applies the same access policy filter when surfacing the boost.
 */
@Injectable()
export class BoostService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
    private readonly blockMute: BlockMuteService,
    private readonly analytics: AnalyticsService,
  ) {}

  async toggle(postId: string, viewer: RequestUser): Promise<BoostState> {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      include: { room: true },
    });
    if (!post || post.status === 'DELETED' || post.status === 'HIDDEN') {
      throw new NotFoundException(`Post not found: ${postId}`);
    }
    await this.access.assertCanReadRoomBySlug(post.room.slug, viewer);
    if (post.authorId !== viewer.id) {
      // P6.2: don't let a blocked-pair amplify each other.
      await assertNotBlocked(this.blockMute, viewer.id, post.authorId);
    }

    const existing = await this.prisma.postBoost.findUnique({
      where: {
        postId_boosterId: { postId, boosterId: viewer.id },
      },
    });

    const result = await this.prisma.$transaction(async (tx) => {
      if (existing) {
        await tx.postBoost.delete({ where: { id: existing.id } });
        const updated = await tx.post.update({
          where: { id: postId },
          data: { boostCount: { decrement: 1 } },
          select: { boostCount: true },
        });
        return {
          boost_count: Math.max(0, updated.boostCount),
          boosted_by_me: false,
        };
      }
      await tx.postBoost.create({
        data: { postId, boosterId: viewer.id },
      });
      const updated = await tx.post.update({
        where: { id: postId },
        data: { boostCount: { increment: 1 } },
        select: { boostCount: true },
      });
      return {
        boost_count: updated.boostCount,
        boosted_by_me: true,
      };
    });

    this.analytics.record({
      actorId: viewer.id,
      eventType: 'POST_BOOSTED',
      payload: {
        post_id: postId,
        action: result.boosted_by_me ? 'BOOST' : 'UNBOOST',
      },
    });

    return result;
  }

  /**
   * Batch helper used by the timeline serializer: returns the set of
   * post ids the viewer has boosted from the given candidates.
   */
  async boostedSetFor(
    viewerId: string,
    postIds: string[],
  ): Promise<Set<string>> {
    if (postIds.length === 0) return new Set();
    const rows = await this.prisma.postBoost.findMany({
      where: { boosterId: viewerId, postId: { in: postIds } },
      select: { postId: true },
    });
    return new Set(rows.map((r) => r.postId));
  }
}
