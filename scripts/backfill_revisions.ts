/**
 * P2.1 backfill — guarantee every `knowledge_blocks` row has a
 * version=1 SEED row in `knowledge_block_revisions`. Skips blocks
 * that already have any revision (no overwrite). After this script,
 * `KnowledgeRevisionService.list` returns at least one entry for
 * every block in the DB.
 *
 * Idempotent: a re-run inserts zero rows.
 *
 * Usage:
 *   DATABASE_URL=... node --import tsx scripts/backfill_revisions.ts [--dry-run]
 */
import { PrismaClient } from '@prisma/client';

const dryRun = process.argv.includes('--dry-run');
const prisma = new PrismaClient();

async function main() {
  // KnowledgeBlock has no created_at column, so the SEED revision
  // borrows updated_at as a best-effort historical timestamp.
  const blocks = await prisma.knowledgeBlock.findMany({
    select: {
      id: true,
      blockType: true,
      title: true,
      body: true,
      updatedAt: true,
    },
  });

  const blockIds = blocks.map((b) => b.id);
  const existing = await prisma.knowledgeBlockRevision.findMany({
    where: { blockId: { in: blockIds } },
    select: { blockId: true },
  });
  const haveAny = new Set(existing.map((r) => r.blockId));

  const missing = blocks.filter((b) => !haveAny.has(b.id));
  if (missing.length === 0) {
    console.log(
      `[backfill_revisions] no missing rows (blocks=${blocks.length}); dry_run=${dryRun}`,
    );
    return;
  }

  let inserted = 0;
  if (!dryRun) {
    // createMany is faster but won't return changedAt-from-block, so a
    // small loop here keeps timestamps faithful to the seed era.
    for (const b of missing) {
      await prisma.knowledgeBlockRevision.create({
        data: {
          blockId: b.id,
          version: 1,
          blockType: b.blockType,
          title: b.title,
          body: b.body,
          changedById: null,
          changedAt: b.updatedAt,
          contributionId: null,
          source: 'SEED',
        },
      });
      inserted += 1;
    }
  } else {
    inserted = missing.length;
  }

  console.log(
    `[backfill_revisions] blocks=${blocks.length} missing=${missing.length} inserted=${inserted} dry_run=${dryRun}`,
  );
}

main()
  .catch((e) => {
    console.error('backfill_revisions failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
