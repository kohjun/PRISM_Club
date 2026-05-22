/**
 * P3.6 backfill — promote the legacy `posts.recruitment_fields` JSON
 * into proper rows on `recruitment_posts` so the application-tracking
 * surface can find them. Only `RECRUITMENT` posts are considered; we
 * skip rows that already have a sibling `recruitment_posts` entry.
 *
 * Idempotent: re-running inserts zero rows. We never overwrite an
 * existing recruitment_posts row — if the JSON drifted from the
 * dedicated row, the dedicated row wins (the JSON is the deprecated
 * source).
 *
 * Status mapping:
 *   recruitmentFields.status === 'CLOSED'   → CLOSED
 *   recruitmentFields.status === 'FILLED'   → FILLED
 *   anything else / missing                 → OPEN
 *
 * Usage:
 *   DATABASE_URL=... node --import tsx scripts/backfill_recruitment_posts.ts [--dry-run]
 */
import { PrismaClient } from '@prisma/client';

const dryRun = process.argv.includes('--dry-run');
const prisma = new PrismaClient();

interface LegacyRecruitmentFields {
  capacity?: number | string;
  status?: string;
  deadline_at?: string;
}

function pickStatus(raw: string | undefined): string {
  if (raw === 'CLOSED' || raw === 'FILLED' || raw === 'CANCELLED') return raw;
  return 'OPEN';
}

function pickCapacity(v: unknown): number | null {
  if (typeof v === 'number' && Number.isFinite(v) && v > 0) return Math.trunc(v);
  if (typeof v === 'string') {
    const n = Number.parseInt(v, 10);
    if (Number.isFinite(n) && n > 0) return n;
  }
  return null;
}

function pickDeadline(v: unknown): Date | null {
  if (typeof v !== 'string' || v.length === 0) return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

async function main() {
  const posts = await prisma.post.findMany({
    where: { postType: 'RECRUITMENT' },
    select: {
      id: true,
      recruitmentFields: true,
    },
  });

  const ids = posts.map((p) => p.id);
  const existing = await prisma.recruitmentPost.findMany({
    where: { postId: { in: ids } },
    select: { postId: true },
  });
  const haveRow = new Set(existing.map((r) => r.postId));

  const missing = posts.filter((p) => !haveRow.has(p.id));
  if (missing.length === 0) {
    console.log(
      `[backfill_recruitment_posts] no missing rows (recruitment posts=${posts.length}); dry_run=${dryRun}`,
    );
    return;
  }

  let inserted = 0;
  for (const p of missing) {
    const raw = (p.recruitmentFields ?? {}) as LegacyRecruitmentFields;
    const status = pickStatus(raw.status);
    const capacity = pickCapacity(raw.capacity);
    const deadlineAt = pickDeadline(raw.deadline_at);
    if (!dryRun) {
      await prisma.recruitmentPost.create({
        data: {
          postId: p.id,
          capacity,
          status,
          deadlineAt,
        },
      });
    }
    inserted += 1;
  }

  console.log(
    `[backfill_recruitment_posts] recruitment_posts=${posts.length} missing=${missing.length} inserted=${inserted} dry_run=${dryRun}`,
  );
}

main()
  .catch((e) => {
    console.error('backfill_recruitment_posts failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
