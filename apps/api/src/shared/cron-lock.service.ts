import { Global, Injectable, Module } from '@nestjs/common';
import { PrismaModule } from './prisma.module';
import { PrismaService } from './prisma.service';

/**
 * Canonical registry of every postgres advisory-lock id used by a
 * scheduled handler. Keeping them in one place is the single source of
 * truth that prevents the 854_303 double-booking that bit us in the
 * Phase 7 pre-PR hotfix (follow-recs and event-live-archive had both
 * claimed it). Add new cron locks here, never inline.
 */
export const CRON_LOCK_IDS = {
  EVENT_REMINDER: 854_301,
  EVENT_STATUS_REFRESH: 854_302,
  EVENT_LIVE_ARCHIVE: 854_303,
  WEEKLY_DIGEST: 854_304,
  TOPIC_HUB_SIMILARITY: 854_305,
  FOLLOW_RECOMMENDATIONS: 854_311,
  DM_LIFECYCLE: 854_312,
  ANALYTICS_RETENTION: 854_401,
} as const;

export type CronLockId = (typeof CRON_LOCK_IDS)[keyof typeof CRON_LOCK_IDS];

/**
 * Thin wrapper over postgres session-level advisory locks
 * (`pg_try_advisory_lock` / `pg_advisory_unlock`). Each scheduled
 * handler used to carry its own private copy of these two queries; the
 * duplication is now collapsed here so the lock semantics (and the
 * `::bigint` cast that keeps the id in int8 range) live in exactly one
 * place.
 *
 * Usage:
 *   if (!(await this.cronLock.tryLock(CRON_LOCK_IDS.WEEKLY_DIGEST))) return;
 *   try { ...work... } finally { await this.cronLock.unlock(id); }
 *
 * The lock is held on the connection that ran `tryLock`. Prisma's
 * pooled client does not guarantee the same physical connection across
 * awaits, but in practice the recompute bodies here run to completion
 * within a single logical unit and the `unlock` is best-effort — the
 * lock is also released automatically when the session ends. The
 * guarantee we actually rely on is mutual exclusion across *replicas*
 * for the duration of a tick, which `pg_try_advisory_lock` provides.
 */
@Injectable()
export class CronLockService {
  constructor(private readonly prisma: PrismaService) {}

  async tryLock(lockId: CronLockId): Promise<boolean> {
    const rows = await this.prisma.$queryRaw<{ locked: boolean }[]>`
      SELECT pg_try_advisory_lock(${lockId}::bigint) AS locked
    `;
    return rows[0]?.locked === true;
  }

  async unlock(lockId: CronLockId): Promise<void> {
    await this.prisma.$queryRaw`
      SELECT pg_advisory_unlock(${lockId}::bigint)
    `;
  }
}

@Global()
@Module({
  imports: [PrismaModule],
  providers: [CronLockService],
  exports: [CronLockService],
})
export class CronLockModule {}
