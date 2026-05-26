import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import {
  AccessControlService,
  Viewer,
} from '../../shared/access-control.service';

const ADVISORY_LOCK_ID = 854_305;
const TOP_N_PER_HUB = 10;
const MIN_SCORE = 0.05;
// Weights are intentionally hard-coded (not env-tunable) — they encode
// the product position that knowledge / contributor overlap is Club's
// primary similarity signal and room overlap is supporting.
const CONTRIBUTOR_WEIGHT = 0.7;
const ROOM_WEIGHT = 0.3;
const ACTIVE_HUB_CAP = 1_000;

export interface SimilarHubReason {
  shared_contributor_count: number;
  shared_room_count: number;
}

export interface SimilarHubDTO {
  topic_hub: {
    id: string;
    slug: string;
    title: string;
    category_slug: string;
  };
  score: number;
  reason: SimilarHubReason;
  computed_at: string;
}

interface HubCorpus {
  hubId: string;
  contributorIds: Set<string>;
  roomIds: Set<string>;
}

/**
 * P7.1 — Topic Hub similarity recommendations.
 *
 * For every active hub U we precompute the top-{@link TOP_N_PER_HUB}
 * hubs V that share contributors (KnowledgeContribution.contributor ∪
 * KnowledgeBlockRevision.changedBy) and rooms (Category.rooms) with U.
 * Score = 0.7 * |contributors(U)∩|/|contributors(U)∪| + 0.3 * |rooms…|.
 *
 * Multi-replica safe via `pg_try_advisory_lock(854305)`. Daily at
 * 03:30 KST (offset from FollowRecommendationCron at 03:00 so the two
 * Jaccard sweeps don't compete for DB CPU on a single-worker host).
 *
 * Reason field is intentionally small (two integers) so the mobile
 * card can render an explanation chip ("@N명의 공통 기여자",
 * "K개의 공통 방") without a follow-up fetch.
 */
@Injectable()
export class TopicHubSimilarityService {
  private readonly log = new Logger(TopicHubSimilarityService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
  ) {}

  // ---- Read --------------------------------------------------------

  async listForHubSlug(
    slug: string,
    viewer: Viewer,
    limit: number = 5,
  ): Promise<SimilarHubDTO[]> {
    const cap = Math.max(1, Math.min(limit, 20));
    const sourceHub = await this.prisma.topicHub.findFirst({
      where: {
        category: { slug },
      },
      include: { category: { include: { space: true } } },
    });
    if (!sourceHub) {
      throw new NotFoundException(`Topic Hub not found: ${slug}`);
    }
    // Anonymous and member viewers must still pass the source hub's
    // own access policy — we won't reveal similar-from edges of a
    // PLANNER_ONLY hub to a PUBLIC viewer either.
    const allowed = this.access.accessPoliciesAllowedFor(viewer);
    if (!allowed.includes(sourceHub.category.space.accessPolicy)) {
      // Treat as "no recommendations" rather than 403; the calling
      // surface (a recommendation strip) self-hides on empty array.
      return [];
    }

    const rows = await this.prisma.topicHubSimilarity.findMany({
      where: { topicHubId: sourceHub.id },
      orderBy: [{ score: 'desc' }, { similarHubId: 'asc' }],
      take: cap * 2, // over-fetch so we can drop hidden hubs without re-querying
      include: {
        similarHub: {
          include: {
            category: { include: { space: true } },
          },
        },
      },
    });

    const visible = rows.filter((r) =>
      allowed.includes(r.similarHub.category.space.accessPolicy),
    );
    return visible.slice(0, cap).map((r) => this.toDTO(r));
  }

  // ---- Recompute ---------------------------------------------------

  async recomputeAll(): Promise<{ hubs_scanned: number; rows_written: number }> {
    const got = await this._tryLock();
    if (!got) {
      this.log.log('topic-hub similarity skipped — lock held elsewhere');
      return { hubs_scanned: 0, rows_written: 0 };
    }
    try {
      return await this._runRecompute();
    } finally {
      await this._unlock();
    }
  }

  private async _runRecompute(): Promise<{
    hubs_scanned: number;
    rows_written: number;
  }> {
    // 1. Load every active hub with the data we need for similarity.
    const hubs = await this.prisma.topicHub.findMany({
      where: { status: 'PUBLISHED' },
      include: {
        category: { include: { rooms: { select: { id: true, status: true } } } },
        contributions: {
          where: { status: 'APPROVED' },
          select: { contributorId: true },
        },
        blocks: {
          select: {
            id: true,
            revisions: { select: { changedById: true } },
          },
        },
      },
      take: ACTIVE_HUB_CAP,
    });

    if (hubs.length <= 1) {
      return { hubs_scanned: hubs.length, rows_written: 0 };
    }

    const corpora: HubCorpus[] = hubs.map((h) => {
      const contributorIds = new Set<string>();
      for (const c of h.contributions) {
        if (c.contributorId) contributorIds.add(c.contributorId);
      }
      for (const b of h.blocks) {
        for (const rev of b.revisions) {
          if (rev.changedById) contributorIds.add(rev.changedById);
        }
      }
      const roomIds = new Set<string>(
        h.category.rooms
          .filter((r) => r.status === 'ACTIVE')
          .map((r) => r.id),
      );
      return { hubId: h.id, contributorIds, roomIds };
    });

    let written = 0;
    for (const u of corpora) {
      const top = this._topSimilarsFor(u, corpora);
      // Replace previous rows for this hub in one transaction so
      // partial recomputes can't leave half-stale state.
      await this.prisma.$transaction([
        this.prisma.topicHubSimilarity.deleteMany({
          where: { topicHubId: u.hubId },
        }),
        this.prisma.topicHubSimilarity.createMany({
          data: top.map((t) => ({
            topicHubId: u.hubId,
            similarHubId: t.hubId,
            score: t.score,
            reason: {
              schemaVersion: 1,
              shared_contributor_count: t.sharedContributorCount,
              shared_room_count: t.sharedRoomCount,
            },
          })),
        }),
      ]);
      written += top.length;
    }
    return { hubs_scanned: hubs.length, rows_written: written };
  }

  private _topSimilarsFor(
    owner: HubCorpus,
    corpora: HubCorpus[],
  ): Array<{
    hubId: string;
    score: number;
    sharedContributorCount: number;
    sharedRoomCount: number;
  }> {
    const scored: Array<{
      hubId: string;
      score: number;
      sharedContributorCount: number;
      sharedRoomCount: number;
    }> = [];
    for (const other of corpora) {
      if (other.hubId === owner.hubId) continue;
      const cJac = jaccard(owner.contributorIds, other.contributorIds);
      const rJac = jaccard(owner.roomIds, other.roomIds);
      const score = CONTRIBUTOR_WEIGHT * cJac.value + ROOM_WEIGHT * rJac.value;
      if (score < MIN_SCORE) continue;
      scored.push({
        hubId: other.hubId,
        score,
        sharedContributorCount: cJac.intersectionSize,
        sharedRoomCount: rJac.intersectionSize,
      });
    }
    scored.sort((a, b) => b.score - a.score);
    return scored.slice(0, TOP_N_PER_HUB);
  }

  // ---- Lock --------------------------------------------------------

  private async _tryLock(): Promise<boolean> {
    const rows = await this.prisma.$queryRaw<{ locked: boolean }[]>`
      SELECT pg_try_advisory_lock(${ADVISORY_LOCK_ID}::bigint) AS locked
    `;
    return rows[0]?.locked === true;
  }

  private async _unlock(): Promise<void> {
    await this.prisma.$queryRaw`
      SELECT pg_advisory_unlock(${ADVISORY_LOCK_ID}::bigint)
    `;
  }

  // ---- DTO ---------------------------------------------------------

  private toDTO(row: {
    score: number;
    reason: unknown;
    computedAt: Date;
    similarHub: {
      id: string;
      title: string;
      category: { slug: string };
    };
  }): SimilarHubDTO {
    const reason = (row.reason ?? {}) as {
      shared_contributor_count?: number;
      shared_room_count?: number;
    };
    return {
      topic_hub: {
        id: row.similarHub.id,
        // The hub doesn't carry its own slug; the category slug acts as
        // the routing identifier. The mobile surface already navigates
        // by category slug (e.g. `/categories/:slug` then resolving the
        // hub on the server) so we surface it here too.
        slug: row.similarHub.category.slug,
        title: row.similarHub.title,
        category_slug: row.similarHub.category.slug,
      },
      score: row.score,
      reason: {
        shared_contributor_count: reason.shared_contributor_count ?? 0,
        shared_room_count: reason.shared_room_count ?? 0,
      },
      computed_at: row.computedAt.toISOString(),
    };
  }
}

function jaccard(
  a: Set<string>,
  b: Set<string>,
): { value: number; intersectionSize: number } {
  if (a.size === 0 && b.size === 0) {
    return { value: 0, intersectionSize: 0 };
  }
  let intersection = 0;
  // Walk the smaller set so the inner `has()` lookup runs on the
  // larger set — same number of comparisons either way but slightly
  // friendlier to the V8 inline cache.
  const [small, large] = a.size <= b.size ? [a, b] : [b, a];
  for (const v of small) {
    if (large.has(v)) intersection += 1;
  }
  const union = a.size + b.size - intersection;
  if (union === 0) return { value: 0, intersectionSize: 0 };
  return { value: intersection / union, intersectionSize: intersection };
}
