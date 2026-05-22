import { Global, Injectable, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';
import { Viewer } from './access-control.service';

export type TrustTier = 'NEW' | 'MEMBER' | 'TRUSTED' | 'PLANNER';

export interface TrustScore {
  tier: TrustTier;
  score: number;
  reasons: string[];
}

const NEW_AGE_HOURS = 24 * 7; // <7 days = NEW
const TRUSTED_APPROVED_FLOOR = 5;

/**
 * Single source-of-truth tier for rate limiting (P5.1) + spam
 * automation bypass (P5.2). Composed from data the system already
 * collects:
 *   - account age (users.created_at)
 *   - role grants  (user_roles)
 *   - approved contribution count (contribution_reputation /
 *     knowledge_contributions fallback)
 *
 * The four tiers correspond to escalating allowances at the
 * downstream consumers:
 *   NEW       — fresh signup, tightest throttle; first target for
 *               duplicate-post / report-flood automation.
 *   MEMBER    — default for anyone past 7d with no role.
 *   TRUSTED   — N approved contributions or upvotes from peers;
 *               relaxed throttle, bypasses NEW-only spam rules.
 *   PLANNER   — VERIFIED_PLANNER / ADMIN; most generous limits and
 *               full bypass of new-user automation.
 */
@Injectable()
export class TrustScoreService {
  constructor(private readonly prisma: PrismaService) {}

  async tierFor(viewer: Viewer & { id: string }): Promise<TrustScore> {
    if (
      viewer.roles.includes('ADMIN') ||
      viewer.roles.includes('VERIFIED_PLANNER')
    ) {
      return { tier: 'PLANNER', score: 1.0, reasons: ['role'] };
    }
    if (viewer.roles.includes('CURATOR') || viewer.roles.includes('MODERATOR')) {
      // Curator/Moderator gets PLANNER-equivalent allowances on the
      // throttle side — they're trusted by the platform.
      return { tier: 'PLANNER', score: 1.0, reasons: ['role'] };
    }

    const [user, reputation] = await Promise.all([
      this.prisma.user.findUnique({
        where: { id: viewer.id },
        select: { createdAt: true },
      }),
      this.prisma.contributionReputation.findUnique({
        where: { userId: viewer.id },
      }),
    ]);

    const reasons: string[] = [];
    const now = Date.now();
    const ageHours = user
      ? (now - user.createdAt.getTime()) / (60 * 60 * 1000)
      : 0;
    if (ageHours < NEW_AGE_HOURS) {
      reasons.push(`age:${Math.floor(ageHours)}h`);
      return { tier: 'NEW', score: 0.1, reasons };
    }

    const approvedCount = reputation?.approvedCount ?? 0;
    if (approvedCount >= TRUSTED_APPROVED_FLOOR) {
      reasons.push(`approved:${approvedCount}`);
      return { tier: 'TRUSTED', score: 0.7, reasons };
    }
    reasons.push(`age:${Math.floor(ageHours)}h`, `approved:${approvedCount}`);
    return { tier: 'MEMBER', score: 0.4, reasons };
  }

  /** Synchronous tier inference when only the viewer (no DB) is in
   *  hand — e.g. inside a guard's onResponse hook where we cannot
   *  await. Returns PLANNER for privileged role bearers, MEMBER for
   *  everyone else. Use `tierFor` when you can afford a DB hit. */
  syncTierFor(viewer: Viewer): TrustTier {
    if (
      viewer.roles.includes('ADMIN') ||
      viewer.roles.includes('VERIFIED_PLANNER') ||
      viewer.roles.includes('CURATOR') ||
      viewer.roles.includes('MODERATOR')
    ) {
      return 'PLANNER';
    }
    return 'MEMBER';
  }
}

@Global()
@Module({
  imports: [],
  providers: [TrustScoreService],
  exports: [TrustScoreService],
})
export class TrustScoreModule {}
