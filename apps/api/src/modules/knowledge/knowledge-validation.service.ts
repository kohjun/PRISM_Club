import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import {
  AccessControlService,
  Viewer,
} from '../../shared/access-control.service';

const SIGNAL_REVISION_WEIGHT = 2;
const SIGNAL_APPROVAL_WEIGHT = 3;
const SIGNAL_REPUTATION_WEIGHT = 0.5;
const SIGNAL_AGE_WEIGHT = 0.1;
const AGE_CAP_DAYS = 30;
const LABEL_THRESHOLD_PARTIAL = 6;
const LABEL_THRESHOLD_STRONG = 16;

export interface ValidationSignals {
  revisions: number;
  approvals: number;
  avg_reputation: number;
  age_days: number;
}

export interface ValidationDTO {
  block_id: string;
  score: number;
  label: string;
  signals: ValidationSignals;
  computed_at: string;
}

export type ChainRole = 'SEED' | 'CONTRIBUTION' | 'ADMIN';

export interface ChainEntryDTO {
  user_id: string | null;
  nickname: string | null;
  role_in_chain: ChainRole;
  acted_at: string;
  revision_version: number;
  contribution_id: string | null;
}

export interface ChainDTO {
  block_id: string;
  items: ChainEntryDTO[];
}

/**
 * P7.2 — Knowledge block "validation strength" score + contribution
 * chain timeline.
 *
 * Both surfaces read from KnowledgeBlockRevision +
 * KnowledgeContribution + ContributionReputation. The score is a
 * deterministic composite (no ML, no opaque ranking) so the mobile
 * badge can attach a "왜 이 점수인가" sheet that lists the same four
 * signals back to the user.
 *
 * Formula:
 *   raw_score = revisions * 2
 *             + approvals * 3
 *             + avg_reputation * 0.5
 *             + min(age_days, 30) * 0.1
 *
 * Mapping (calibrated for the seed corpus; recheck in production):
 *   raw < 6   → "검증 부족"
 *   6 ≤ raw < 16 → "검증 진행 중"
 *   raw ≥ 16  → "충분히 검증됨"
 *
 * The score is computed read-time per request. With the
 * `knowledge_contributions_target_status_idx` index landed in this
 * PR's migration, each call is 3 lightweight queries; a future v2 can
 * cache the score on the block row if we observe N+1 patterns in the
 * timeline.
 */
@Injectable()
export class KnowledgeValidationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
  ) {}

  async getFor(blockId: string, viewer: Viewer): Promise<ValidationDTO> {
    const block = await this._loadBlockOrThrow(blockId, viewer);

    const [revisions, approvals, contributorIds] = await Promise.all([
      this.prisma.knowledgeBlockRevision.count({ where: { blockId } }),
      this.prisma.knowledgeContribution.count({
        where: { targetBlockId: blockId, status: 'APPROVED' },
      }),
      this.prisma.knowledgeContribution.findMany({
        where: { targetBlockId: blockId, status: 'APPROVED' },
        select: { contributorId: true },
      }),
    ]);

    const ids = Array.from(new Set(contributorIds.map((c) => c.contributorId)));
    let avgReputation = 0;
    if (ids.length > 0) {
      const agg = await this.prisma.contributionReputation.aggregate({
        where: { userId: { in: ids } },
        _avg: { weightedScore: true },
      });
      // weightedScore is `numeric(10,2)` → Prisma.Decimal — coerce
      // through .toNumber() for the float math.
      avgReputation = agg._avg.weightedScore?.toNumber() ?? 0;
    }

    const ageDays = Math.min(
      Math.floor(
        (Date.now() - block.updatedAt.getTime()) / (1000 * 60 * 60 * 24),
      ),
      AGE_CAP_DAYS,
    );
    const rawScore =
      revisions * SIGNAL_REVISION_WEIGHT +
      approvals * SIGNAL_APPROVAL_WEIGHT +
      avgReputation * SIGNAL_REPUTATION_WEIGHT +
      Math.max(0, ageDays) * SIGNAL_AGE_WEIGHT;

    const score = Math.round(rawScore * 10) / 10;
    return {
      block_id: blockId,
      score,
      label: this._labelFor(score),
      signals: {
        revisions,
        approvals,
        avg_reputation: Math.round(avgReputation * 10) / 10,
        age_days: Math.max(0, ageDays),
      },
      computed_at: new Date().toISOString(),
    };
  }

  async chainFor(blockId: string, viewer: Viewer): Promise<ChainDTO> {
    await this._loadBlockOrThrow(blockId, viewer);
    const rows = await this.prisma.knowledgeBlockRevision.findMany({
      where: { blockId },
      orderBy: [{ changedAt: 'asc' }, { version: 'asc' }],
      include: {
        changedBy: { include: { profile: true } },
      },
    });
    return {
      block_id: blockId,
      items: rows.map((r) => ({
        user_id: r.changedById,
        nickname: r.changedBy?.profile?.nickname ?? null,
        role_in_chain: this._roleFor(r.source),
        acted_at: r.changedAt.toISOString(),
        revision_version: r.version,
        contribution_id: r.contributionId,
      })),
    };
  }

  /**
   * Batch-friendly variant for inlining the score onto every block in
   * a hub bundle. Reuses the same formula; runs one query per signal
   * across the full block list using `groupBy` so the per-block cost
   * stays bounded as the hub grows.
   */
  async scoresForBlocks(
    blockIds: string[],
  ): Promise<Map<string, ValidationDTO>> {
    const result = new Map<string, ValidationDTO>();
    if (blockIds.length === 0) return result;

    const [blocks, revisionRows, approvalRows] = await Promise.all([
      this.prisma.knowledgeBlock.findMany({
        where: { id: { in: blockIds } },
        select: { id: true, updatedAt: true },
      }),
      this.prisma.knowledgeBlockRevision.groupBy({
        by: ['blockId'],
        where: { blockId: { in: blockIds } },
        _count: { _all: true },
      }),
      this.prisma.knowledgeContribution.findMany({
        where: { targetBlockId: { in: blockIds }, status: 'APPROVED' },
        select: { targetBlockId: true, contributorId: true },
      }),
    ]);

    const revisionsBy = new Map<string, number>();
    for (const r of revisionRows) {
      revisionsBy.set(r.blockId, r._count._all);
    }

    const approvalsBy = new Map<string, number>();
    const contributorsBy = new Map<string, Set<string>>();
    for (const c of approvalRows) {
      if (!c.targetBlockId) continue;
      approvalsBy.set(c.targetBlockId, (approvalsBy.get(c.targetBlockId) ?? 0) + 1);
      if (!contributorsBy.has(c.targetBlockId)) {
        contributorsBy.set(c.targetBlockId, new Set());
      }
      contributorsBy.get(c.targetBlockId)!.add(c.contributorId);
    }

    // Single aggregate over the union of contributors across all blocks
    // — we'll average per-block client-side from the cached per-user
    // reputation map. This keeps the SQL cost at O(1) regardless of
    // block count.
    const allContributorIds = new Set<string>();
    for (const set of contributorsBy.values()) {
      for (const id of set) allContributorIds.add(id);
    }
    const reps = allContributorIds.size
      ? await this.prisma.contributionReputation.findMany({
          where: { userId: { in: [...allContributorIds] } },
          select: { userId: true, weightedScore: true },
        })
      : [];
    const repBy = new Map<string, number>();
    for (const r of reps) {
      // weightedScore is `numeric(10,2)` → Prisma.Decimal — coerce
      // through .toNumber() for the float math below.
      repBy.set(r.userId, r.weightedScore.toNumber());
    }

    const now = Date.now();
    for (const block of blocks) {
      const revisions = revisionsBy.get(block.id) ?? 0;
      const approvals = approvalsBy.get(block.id) ?? 0;
      const contribIds = contributorsBy.get(block.id) ?? new Set<string>();
      const reputations: number[] = [];
      for (const id of contribIds) {
        reputations.push(repBy.get(id) ?? 0);
      }
      const avgRep = reputations.length
        ? reputations.reduce((a, b) => a + b, 0) / reputations.length
        : 0;
      const ageDays = Math.min(
        Math.floor((now - block.updatedAt.getTime()) / (1000 * 60 * 60 * 24)),
        AGE_CAP_DAYS,
      );
      const rawScore =
        revisions * SIGNAL_REVISION_WEIGHT +
        approvals * SIGNAL_APPROVAL_WEIGHT +
        avgRep * SIGNAL_REPUTATION_WEIGHT +
        Math.max(0, ageDays) * SIGNAL_AGE_WEIGHT;
      const score = Math.round(rawScore * 10) / 10;
      result.set(block.id, {
        block_id: block.id,
        score,
        label: this._labelFor(score),
        signals: {
          revisions,
          approvals,
          avg_reputation: Math.round(avgRep * 10) / 10,
          age_days: Math.max(0, ageDays),
        },
        computed_at: new Date(now).toISOString(),
      });
    }
    return result;
  }

  private async _loadBlockOrThrow(
    blockId: string,
    viewer: Viewer,
  ): Promise<{ id: string; updatedAt: Date }> {
    const block = await this.prisma.knowledgeBlock.findUnique({
      where: { id: blockId },
      include: {
        hub: { include: { category: { include: { space: true } } } },
      },
    });
    if (!block) {
      throw new NotFoundException(`Knowledge block not found: ${blockId}`);
    }
    // Mirror the revision service's gate (`hub.category.space.accessPolicy`)
    // so the validation surface honours the same Planner-only rules.
    if (
      !this.access
        .accessPoliciesAllowedFor(viewer)
        .includes(block.hub.category.space.accessPolicy)
    ) {
      throw new NotFoundException(`Knowledge block not found: ${blockId}`);
    }
    return { id: block.id, updatedAt: block.updatedAt };
  }

  private _labelFor(score: number): string {
    if (score >= LABEL_THRESHOLD_STRONG) return '충분히 검증됨';
    if (score >= LABEL_THRESHOLD_PARTIAL) return '검증 진행 중';
    return '검증 부족';
  }

  private _roleFor(source: string): ChainRole {
    if (source === 'CONTRIBUTION') return 'CONTRIBUTION';
    if (source === 'ADMIN') return 'ADMIN';
    return 'SEED';
  }
}
