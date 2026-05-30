import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService, Viewer } from '../../shared/access-control.service';
import { CronLockService, CRON_LOCK_IDS } from '../../shared/cron-lock.service';

const TOP_N_PER_USER = 20;
const MIN_SHARED_HUBS = 1;
const ACTIVE_USER_FLOOR_HOURS = 90 * 24; // recompute only for users active within 90d

export interface FollowRecommendationDTO {
  id: string;
  recommended_user: {
    id: string;
    nickname: string | null;
  };
  score: number;
  reason: {
    shared_hub_slugs: string[];
    shared_room_count: number;
  };
  computed_at: string;
}

/**
 * P4.3 follow recommendations.
 *
 * For each "owner" user U:
 *   1. Find the set of category ids U follows rooms in (= Topic Hubs U is engaged with).
 *   2. Candidate set V = users following any of those categories' rooms (minus U + already-followed).
 *   3. Jaccard score = |hubs(U) ∩ hubs(V)| / |hubs(U) ∪ hubs(V)|.
 *   4. Persist top 20.
 *
 * Multi-replica safe via `pg_try_advisory_lock(854311)`. Daily 03:00 KST.
 */
@Injectable()
export class FollowRecommendationService {
  private readonly log = new Logger(FollowRecommendationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
    private readonly cronLock: CronLockService,
  ) {}

  // -- Read ----------------------------------------------------------

  async listForUser(
    viewer: Viewer & { id: string },
    limit: number = 10,
  ): Promise<FollowRecommendationDTO[]> {
    const cap = Math.max(1, Math.min(limit, 30));
    const allowed = this.access.accessPoliciesAllowedFor(viewer);

    // Pull the top candidates, then drop any that we can't render to
    // the caller (already-followed, missing profile, planner-only
    // hub-overlap users that this viewer can't see).
    const already = new Set(
      (
        await this.prisma.userFollow.findMany({
          where: { followerId: viewer.id },
          select: { followedId: true },
        })
      ).map((r) => r.followedId),
    );

    const rows = await this.prisma.followRecommendation.findMany({
      where: { userId: viewer.id },
      orderBy: [{ score: 'desc' }, { computedAt: 'desc' }],
      take: cap * 2, // overshoot, then drop already-followed
      include: {
        recommendedUser: { include: { profile: true } },
      },
    });
    const items: FollowRecommendationDTO[] = [];
    for (const row of rows) {
      if (already.has(row.recommendedUserId)) continue;
      if (row.recommendedUser.status !== 'ACTIVE') continue;
      // Filter by space access: the recommendation reason cites hub
      // slugs the candidate follows in; if all those hubs are in
      // spaces the viewer can't read, hide the candidate to avoid
      // surfacing PLANNER_ONLY-only users to PUBLIC viewers.
      const reason = row.reason as { shared_hub_slugs?: string[]; shared_room_count?: number };
      const visibleHubs = await this._filterHubsByAccess(
        reason.shared_hub_slugs ?? [],
        allowed,
      );
      if (visibleHubs.length === 0) continue;
      items.push({
        id: row.id,
        recommended_user: {
          id: row.recommendedUser.id,
          nickname: row.recommendedUser.profile?.nickname ?? null,
        },
        score: row.score,
        reason: {
          shared_hub_slugs: visibleHubs,
          shared_room_count: reason.shared_room_count ?? 0,
        },
        computed_at: row.computedAt.toISOString(),
      });
      if (items.length >= cap) break;
    }
    return items;
  }

  // -- Recompute -----------------------------------------------------

  /**
   * Daily recompute. Advisory-locked. Iterates active users (those
   * who have followed at least one room ever — pruning ghost accounts).
   */
  async recomputeAll(): Promise<{ users_scanned: number; rows_written: number }> {
    const got = await this.cronLock.tryLock(
      CRON_LOCK_IDS.FOLLOW_RECOMMENDATIONS,
    );
    if (!got) {
      this.log.log('recompute skipped — lock held by another instance');
      return { users_scanned: 0, rows_written: 0 };
    }
    try {
      return await this._runRecompute();
    } finally {
      await this.cronLock.unlock(CRON_LOCK_IDS.FOLLOW_RECOMMENDATIONS);
    }
  }

  private async _runRecompute(): Promise<{
    users_scanned: number;
    rows_written: number;
  }> {
    // Active users = anyone with at least one RoomFollow row OR
    // anyone whose account was created in the last ACTIVE_USER_FLOOR_HOURS.
    const cutoff = new Date(
      Date.now() - ACTIVE_USER_FLOOR_HOURS * 60 * 60 * 1000,
    );
    const activeUserIds = await this.prisma.user.findMany({
      where: {
        status: 'ACTIVE',
        OR: [
          { follows: { some: {} } },
          { createdAt: { gte: cutoff } },
        ],
      },
      select: { id: true },
      take: 5_000, // cap on the worst case; raise once we observe production volume
    });

    let written = 0;
    for (const u of activeUserIds) {
      const top = await this._topCandidatesFor(u.id);
      if (top.length === 0) continue;
      // Replace previous rows for this user in one transaction.
      await this.prisma.$transaction([
        this.prisma.followRecommendation.deleteMany({
          where: { userId: u.id },
        }),
        this.prisma.followRecommendation.createMany({
          data: top.map((t) => ({
            userId: u.id,
            recommendedUserId: t.candidateId,
            score: t.score,
            reason: {
              shared_hub_slugs: t.sharedHubSlugs,
              shared_room_count: t.sharedRoomCount,
            },
          })),
        }),
      ]);
      written += top.length;
    }
    return { users_scanned: activeUserIds.length, rows_written: written };
  }

  private async _topCandidatesFor(userId: string): Promise<
    Array<{
      candidateId: string;
      score: number;
      sharedHubSlugs: string[];
      sharedRoomCount: number;
    }>
  > {
    // 1. owner's hub (category) set
    const ownerFollows = await this.prisma.roomFollow.findMany({
      where: { userId },
      include: { room: { include: { category: true } } },
    });
    if (ownerFollows.length === 0) return [];
    const ownerHubIds = new Set(ownerFollows.map((f) => f.room.categoryId));

    // 2. candidates = other users who follow at least one room whose
    //    category is in ownerHubIds. We pull their follows in one batch
    //    so we can compute Jaccard in memory without N+1 queries.
    const candidateFollows = await this.prisma.roomFollow.findMany({
      where: {
        userId: { not: userId },
        room: { categoryId: { in: [...ownerHubIds] } },
      },
      include: { room: { include: { category: true } } },
    });
    if (candidateFollows.length === 0) return [];

    // Build candidate → hubId set, candidate → shared room count.
    const candHubs: Map<string, Set<string>> = new Map();
    const candRooms: Map<string, number> = new Map();
    for (const f of candidateFollows) {
      if (!candHubs.has(f.userId)) candHubs.set(f.userId, new Set());
      candHubs.get(f.userId)!.add(f.room.categoryId);
      candRooms.set(f.userId, (candRooms.get(f.userId) ?? 0) + 1);
    }

    // To compute Jaccard properly we also need each candidate's *full*
    // hub set (not just the overlap with owner) — pull it in one batch
    // for the union denominator.
    const allCandidateFollows = await this.prisma.roomFollow.findMany({
      where: { userId: { in: [...candHubs.keys()] } },
      include: { room: { include: { category: true } } },
    });
    const candFullHubs: Map<string, Set<string>> = new Map();
    for (const f of allCandidateFollows) {
      if (!candFullHubs.has(f.userId)) candFullHubs.set(f.userId, new Set());
      candFullHubs.get(f.userId)!.add(f.room.categoryId);
    }

    // Drop candidates the owner already follows.
    const ownerFollowsUserIds = new Set(
      (
        await this.prisma.userFollow.findMany({
          where: { followerId: userId },
          select: { followedId: true },
        })
      ).map((r) => r.followedId),
    );

    // Compute Jaccard scores.
    const scored: Array<{
      candidateId: string;
      score: number;
      sharedHubSlugs: string[];
      sharedRoomCount: number;
    }> = [];
    const hubIdsToSlug = new Map<string, string>();
    for (const f of ownerFollows) {
      hubIdsToSlug.set(f.room.categoryId, f.room.category.slug);
    }
    for (const f of allCandidateFollows) {
      hubIdsToSlug.set(f.room.categoryId, f.room.category.slug);
    }

    for (const [candId, candSet] of candFullHubs) {
      if (ownerFollowsUserIds.has(candId)) continue;
      const intersection: Set<string> = new Set();
      for (const h of candSet) {
        if (ownerHubIds.has(h)) intersection.add(h);
      }
      if (intersection.size < MIN_SHARED_HUBS) continue;
      const unionSize =
        ownerHubIds.size + candSet.size - intersection.size;
      if (unionSize === 0) continue;
      const score = intersection.size / unionSize;
      const sharedHubSlugs: string[] = [];
      for (const h of intersection) {
        const slug = hubIdsToSlug.get(h);
        if (slug) sharedHubSlugs.push(slug);
      }
      scored.push({
        candidateId: candId,
        score,
        sharedHubSlugs,
        sharedRoomCount: candRooms.get(candId) ?? 0,
      });
    }

    scored.sort((a, b) => b.score - a.score);
    return scored.slice(0, TOP_N_PER_USER);
  }

  private async _filterHubsByAccess(
    slugs: string[],
    allowed: string[],
  ): Promise<string[]> {
    if (slugs.length === 0) return [];
    const cats = await this.prisma.category.findMany({
      where: { slug: { in: slugs } },
      include: { space: true },
    });
    return cats
      .filter((c) => allowed.includes(c.space.accessPolicy))
      .map((c) => c.slug);
  }
}
