import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import {
  ReputationDTO,
  ReputationLeaderboardDTO,
  ReputationLeaderboardEntryDTO,
} from './dto/reputation.dto';

const DEFAULT_LEADERBOARD_LIMIT = 20;
const MAX_LEADERBOARD_LIMIT = 100;

/**
 * Read-only surface over the P2.2 contribution_reputation table. The
 * write side lives in KnowledgeContributionService.resolve / _applyApprove
 * — that's where the contribution status transition originates and where
 * the increment must stay transactional.
 */
@Injectable()
export class ContributionReputationService {
  constructor(private readonly prisma: PrismaService) {}

  async getForUser(userId: string): Promise<ReputationDTO> {
    const row = await this.prisma.contributionReputation.findUnique({
      where: { userId },
    });
    if (!row) {
      // No resolved contributions yet — return a synthetic zero row so
      // the caller doesn't need a null branch.
      return {
        user_id: userId,
        approved_count: 0,
        rejected_count: 0,
        needs_changes_count: 0,
        withdrawn_count: 0,
        weighted_score: 0,
        last_resolved_at: null,
      };
    }
    return this.toDTO(row);
  }

  async leaderboard(
    limit: number = DEFAULT_LEADERBOARD_LIMIT,
  ): Promise<ReputationLeaderboardDTO> {
    const cap = Math.max(1, Math.min(limit, MAX_LEADERBOARD_LIMIT));
    const rows = await this.prisma.contributionReputation.findMany({
      orderBy: [
        { weightedScore: 'desc' },
        { approvedCount: 'desc' },
        { lastResolvedAt: 'desc' },
      ],
      take: cap,
      include: {
        user: { include: { profile: true } },
      },
    });
    const items: ReputationLeaderboardEntryDTO[] = rows.map((r, i) => ({
      ...this.toDTO(r),
      rank: i + 1,
      user: {
        id: r.user.id,
        nickname: r.user.profile?.nickname ?? null,
      },
    }));
    return { items, computed_at: new Date().toISOString() };
  }

  /**
   * Get reputation for a user, asserting the user exists. Surfaces 404
   * when the user id doesn't resolve so callers can distinguish "no row
   * yet" (synthetic zero) from "no such user".
   */
  async getForUserStrict(userId: string): Promise<ReputationDTO> {
    const userExists = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true },
    });
    if (!userExists) {
      throw new NotFoundException(`User not found: ${userId}`);
    }
    return this.getForUser(userId);
  }

  private toDTO(row: {
    userId: string;
    approvedCount: number;
    rejectedCount: number;
    needsChangesCount: number;
    withdrawnCount: number;
    weightedScore: { toString(): string } | number;
    lastResolvedAt: Date | null;
  }): ReputationDTO {
    return {
      user_id: row.userId,
      approved_count: row.approvedCount,
      rejected_count: row.rejectedCount,
      needs_changes_count: row.needsChangesCount,
      withdrawn_count: row.withdrawnCount,
      weighted_score: Number(row.weightedScore),
      last_resolved_at: row.lastResolvedAt
        ? row.lastResolvedAt.toISOString()
        : null,
    };
  }
}
