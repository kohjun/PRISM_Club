/**
 * P2.3 backfill — recompute `reference_items.source_tier` for every
 * row by re-running the live domain → tier classifier against the
 * stored URL.
 *
 * Idempotent: a re-run only updates rows whose tier has changed
 * (e.g. after a new ReferenceSourceRule lands). Safe to run any time.
 *
 * Usage:
 *   DATABASE_URL=... node --import tsx scripts/backfill_reference_tiers.ts [--dry-run]
 */
import { PrismaClient } from '@prisma/client';

const dryRun = process.argv.includes('--dry-run');
const prisma = new PrismaClient();

interface Rule {
  domainPattern: string;
  tier: string;
}

const TIER_PRIORITY: Record<string, number> = {
  OFFICIAL: 1,
  TRUSTED: 2,
  COMMUNITY: 3,
  UNKNOWN: 4,
};

function extractHost(url: string): string | null {
  try {
    return new URL(url).hostname.toLowerCase();
  } catch {
    return null;
  }
}

function matchDomain(host: string, pattern: string): boolean {
  const p = pattern.toLowerCase();
  if (p.startsWith('*.')) {
    return host.endsWith(p.slice(1));
  }
  return host === p;
}

function classify(url: string, rules: Rule[]): string {
  const host = extractHost(url);
  if (!host || rules.length === 0) return 'UNKNOWN';
  const matched = rules.filter((r) => matchDomain(host, r.domainPattern));
  if (matched.length === 0) return 'UNKNOWN';
  matched.sort((a, b) => {
    const pa = TIER_PRIORITY[a.tier] ?? 99;
    const pb = TIER_PRIORITY[b.tier] ?? 99;
    if (pa !== pb) return pa - pb;
    return b.domainPattern.length - a.domainPattern.length;
  });
  return matched[0].tier;
}

async function main() {
  const rules = await prisma.referenceSourceRule.findMany({
    select: { domainPattern: true, tier: true },
  });
  const refs = await prisma.reference.findMany({
    select: { id: true, url: true, sourceTier: true },
  });

  let updated = 0;
  const counts: Record<string, number> = {};
  for (const ref of refs) {
    const next = classify(ref.url, rules);
    counts[next] = (counts[next] ?? 0) + 1;
    if (next !== ref.sourceTier) {
      updated += 1;
      if (!dryRun) {
        await prisma.reference.update({
          where: { id: ref.id },
          data: { sourceTier: next },
        });
      }
    }
  }

  console.log(
    `[backfill_reference_tiers] scanned=${refs.length} updated=${updated} dry_run=${dryRun}`,
  );
  console.log(`  tier histogram (after):`, counts);
}

main()
  .catch((e) => {
    console.error('backfill_reference_tiers failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
