/**
 * P2.2 backfill — recompute `contribution_reputation` aggregates from
 * the `knowledge_contributions` ledger for every contributor that has
 * at least one resolved row.
 *
 * Idempotent: writes via upsert with the latest computed counts and
 * `weighted_score`. Safe to run after the formula changes or after a
 * data migration that resolves a batch of contributions.
 *
 * Formula (floored at 0):
 *   approved*3 - rejected*1 - needs_changes*0.5 - withdrawn*0.2
 *
 * Usage:
 *   DATABASE_URL=... node --import tsx scripts/backfill_reputation.ts [--dry-run]
 */
import { PrismaClient } from '@prisma/client';

const dryRun = process.argv.includes('--dry-run');
const prisma = new PrismaClient();

function computeScore(c: {
  approved: number;
  rejected: number;
  needsChanges: number;
  withdrawn: number;
}): number {
  const raw =
    c.approved * 3 -
    c.rejected * 1 -
    c.needsChanges * 0.5 -
    c.withdrawn * 0.2;
  return Math.max(0, raw);
}

async function main() {
  const rows = await prisma.knowledgeContribution.findMany({
    where: { status: { not: 'PENDING' } },
    select: {
      contributorId: true,
      status: true,
      resolvedAt: true,
      updatedAt: true,
    },
  });

  const agg = new Map<
    string,
    {
      approved: number;
      rejected: number;
      needsChanges: number;
      withdrawn: number;
      lastResolvedAt: Date | null;
    }
  >();

  for (const c of rows) {
    let bucket = agg.get(c.contributorId);
    if (!bucket) {
      bucket = {
        approved: 0,
        rejected: 0,
        needsChanges: 0,
        withdrawn: 0,
        lastResolvedAt: null,
      };
      agg.set(c.contributorId, bucket);
    }
    switch (c.status) {
      case 'APPROVED':
        bucket.approved += 1;
        break;
      case 'REJECTED':
        bucket.rejected += 1;
        break;
      case 'NEEDS_CHANGES':
        bucket.needsChanges += 1;
        break;
      case 'WITHDRAWN':
        bucket.withdrawn += 1;
        break;
    }
    const stamp = c.resolvedAt ?? c.updatedAt;
    if (!bucket.lastResolvedAt || stamp > bucket.lastResolvedAt) {
      bucket.lastResolvedAt = stamp;
    }
  }

  let updated = 0;
  for (const [userId, b] of agg) {
    const score = computeScore(b);
    if (dryRun) {
      updated += 1;
      continue;
    }
    await prisma.contributionReputation.upsert({
      where: { userId },
      create: {
        userId,
        approvedCount: b.approved,
        rejectedCount: b.rejected,
        needsChangesCount: b.needsChanges,
        withdrawnCount: b.withdrawn,
        weightedScore: score,
        lastResolvedAt: b.lastResolvedAt,
      },
      update: {
        approvedCount: b.approved,
        rejectedCount: b.rejected,
        needsChangesCount: b.needsChanges,
        withdrawnCount: b.withdrawn,
        weightedScore: score,
        lastResolvedAt: b.lastResolvedAt,
      },
    });
    updated += 1;
  }

  console.log(
    `[backfill_reputation] contributors=${agg.size} upserted=${updated} dry_run=${dryRun}`,
  );
}

main()
  .catch((e) => {
    console.error('backfill_reputation failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
