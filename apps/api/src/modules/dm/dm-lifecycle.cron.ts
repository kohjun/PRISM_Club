import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../shared/prisma.service';
import {
  CronLockService,
  CRON_LOCK_IDS,
} from '../../shared/cron-lock.service';

const GRACE_DAYS = 30;
const RECRUITMENT_ENDED = ['CLOSED', 'FILLED', 'CANCELLED'];

/**
 * P6.9 — DM channel lifecycle. A single daily cron is the SOLE closer of
 * scoped-DM channels (no per-status-change hooks in the recruitment /
 * contribution services — one source of truth avoids the missed-site
 * leak). Two phases:
 *   A. mark — stamp `workflow_ended_at` on OPEN channels whose workflow
 *      has ended. RECRUITMENT reads the author-canonical
 *      `recruitmentFields` JSON status (the structured
 *      recruitment_posts.status is NOT written on manual close).
 *      CONTRIBUTION uses the contribution's resolvedAt (NEEDS_CHANGES is
 *      terminal, so that timestamp IS the workflow end).
 *   B. sweep — flip OPEN → CLOSED once `workflow_ended_at` is older than
 *      the 30-day grace. UPDATE only; channels are never hard-deleted so
 *      a reported message stays resolvable by a moderator.
 */
@Injectable()
export class DmLifecycleCron {
  private readonly log = new Logger(DmLifecycleCron.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cronLock: CronLockService,
  ) {}

  @Cron('0 0 18 * * *') // 03:00 KST = 18:00 UTC
  async dailyTick(): Promise<void> {
    if (process.env.DM_LIFECYCLE_CRON_ENABLED === '0') return;
    const got = await this.cronLock.tryLock(CRON_LOCK_IDS.DM_LIFECYCLE);
    if (!got) return;
    try {
      await this.run(new Date());
    } catch (e) {
      this.log.warn(
        `dm lifecycle tick failed: ${e instanceof Error ? e.message : String(e)}`,
      );
    } finally {
      await this.cronLock.unlock(CRON_LOCK_IDS.DM_LIFECYCLE);
    }
  }

  async run(now: Date): Promise<{ stamped: number; closed: number }> {
    let stamped = 0;

    // Phase A — stamp workflow_ended_at on OPEN, not-yet-stamped channels.
    const open = await this.prisma.dmChannel.findMany({
      where: { status: 'OPEN', workflowEndedAt: null },
      select: { id: true, scope: true, refId: true },
    });

    const recruitment = open.filter((c) => c.scope === 'RECRUITMENT');
    if (recruitment.length > 0) {
      const postIds = [...new Set(recruitment.map((c) => c.refId))];
      const posts = await this.prisma.post.findMany({
        where: { id: { in: postIds } },
        select: { id: true, recruitmentFields: true },
      });
      const endedPosts = new Set(
        posts
          .filter((p) => {
            const s = (p.recruitmentFields as { status?: string } | null)
              ?.status;
            return s != null && RECRUITMENT_ENDED.includes(s);
          })
          .map((p) => p.id),
      );
      const toStamp = recruitment
        .filter((c) => endedPosts.has(c.refId))
        .map((c) => c.id);
      if (toStamp.length > 0) {
        const r = await this.prisma.dmChannel.updateMany({
          where: { id: { in: toStamp } },
          data: { workflowEndedAt: now },
        });
        stamped += r.count;
      }
    }

    const contribution = open.filter((c) => c.scope === 'CONTRIBUTION');
    if (contribution.length > 0) {
      const cIds = [...new Set(contribution.map((c) => c.refId))];
      const contribs = await this.prisma.knowledgeContribution.findMany({
        where: { id: { in: cIds }, resolvedAt: { not: null } },
        select: { id: true, resolvedAt: true },
      });
      const endedAt = new Map(contribs.map((c) => [c.id, c.resolvedAt]));
      for (const ch of contribution) {
        const ra = endedAt.get(ch.refId);
        if (ra) {
          await this.prisma.dmChannel.update({
            where: { id: ch.id },
            data: { workflowEndedAt: ra },
          });
          stamped += 1;
        }
      }
    }

    // Phase B — close channels whose grace window has elapsed.
    const graceCutoff = new Date(now.getTime() - GRACE_DAYS * 86_400_000);
    const closedRes = await this.prisma.dmChannel.updateMany({
      where: {
        status: 'OPEN',
        workflowEndedAt: { not: null, lt: graceCutoff },
      },
      data: {
        status: 'CLOSED',
        closedAt: now,
        closedReason: 'WORKFLOW_ENDED_GRACE',
      },
    });
    return { stamped, closed: closedRes.count };
  }
}
