import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import {
  AccessControlService,
  Viewer,
} from '../../shared/access-control.service';

const CURATOR_ROLES = ['CURATOR', 'MODERATOR', 'ADMIN'];
const CONTRIBUTIONS_CAP = 50;
const RULES_CAP = 50;

export interface CuratorReputationDTO {
  weighted_score: number;
  approved_count: number;
  rejected_count: number;
  needs_changes_count: number;
  withdrawn_count: number;
}

export interface ResolvedContributionDTO {
  id: string;
  title: string;
  block_type: string;
  category_slug: string;
  resolved_at: string;
}

export interface SourceRuleDTO {
  id: string;
  domain_pattern: string;
  tier: string;
  note: string | null;
  created_at: string;
}

export interface CuratorPortfolioDTO {
  user_id: string;
  is_curator: boolean;
  reputation: CuratorReputationDTO | null;
  resolved_contributions: ResolvedContributionDTO[];
  source_rules: SourceRuleDTO[];
}

/**
 * P6.10 — Curator portfolio.
 *
 * Aggregates a user's curation footprint into one read surface so the
 * work scattered across resolved contributions, source-tier rules, and
 * the P2.2 reputation row becomes a single trust signal. No new schema:
 * everything is derived from existing rows
 * (KnowledgeContribution.resolvedBy, ReferenceSourceRule.createdBy,
 * ContributionReputation).
 *
 * Self-correcting by construction: only `status='APPROVED'`
 * contributions are listed, so if a later ADMIN flips one to REJECTED
 * it silently drops out of the portfolio — no separate prune needed.
 *
 * Visibility: resolved contributions are filtered by the viewer's
 * space accessPolicy, so a PLANNER_ONLY hub contribution never shows
 * to a PUBLIC viewer. Source rules + reputation are curation metadata
 * already public on the profile, so they aren't space-gated.
 */
@Injectable()
export class CuratorPortfolioService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
  ) {}

  async getForUser(
    userId: string,
    viewer: Viewer,
  ): Promise<CuratorPortfolioDTO> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, status: true, roles: { select: { role: true } } },
    });
    if (!user || user.status !== 'ACTIVE') {
      throw new NotFoundException(`User not found: ${userId}`);
    }

    const isCurator = user.roles.some((r) => CURATOR_ROLES.includes(r.role));
    const allowed = this.access.accessPoliciesAllowedFor(viewer);

    const [contributions, rules, reputation] = await Promise.all([
      this.prisma.knowledgeContribution.findMany({
        where: {
          resolvedBy: userId,
          status: 'APPROVED',
          hub: { category: { space: { accessPolicy: { in: allowed } } } },
        },
        include: { hub: { include: { category: true } } },
        orderBy: { resolvedAt: 'desc' },
        take: CONTRIBUTIONS_CAP,
      }),
      this.prisma.referenceSourceRule.findMany({
        where: { createdBy: userId },
        orderBy: { createdAt: 'desc' },
        take: RULES_CAP,
      }),
      this.prisma.contributionReputation.findUnique({ where: { userId } }),
    ]);

    return {
      user_id: userId,
      is_curator: isCurator,
      reputation: reputation
        ? {
            weighted_score: reputation.weightedScore.toNumber(),
            approved_count: reputation.approvedCount,
            rejected_count: reputation.rejectedCount,
            needs_changes_count: reputation.needsChangesCount,
            withdrawn_count: reputation.withdrawnCount,
          }
        : null,
      resolved_contributions: contributions
        .filter((c) => c.resolvedAt != null)
        .map((c) => ({
          id: c.id,
          title: c.proposedTitle,
          block_type: c.proposedBlockType,
          category_slug: c.hub.category.slug,
          resolved_at: (c.resolvedAt as Date).toISOString(),
        })),
      source_rules: rules.map((r) => ({
        id: r.id,
        domain_pattern: r.domainPattern,
        tier: r.tier,
        note: r.note,
        created_at: r.createdAt.toISOString(),
      })),
    };
  }
}
