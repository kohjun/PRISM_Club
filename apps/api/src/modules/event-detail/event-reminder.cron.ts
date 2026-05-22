import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma.service';
import { EventDigestService } from './event-digest.service';
import { EventLiveService } from './event-live.service';

/**
 * Event reminder + status-refresh cron (P3.2).
 *
 * Two responsibilities:
 *   1. `runReminderTick` — every hour, fan out D-1 / H-1 reminders to
 *      INTERESTED|GOING RSVPs whose event lands in the matching
 *      window. Unique `(event_card_id, user_id, reminder_kind)` is
 *      the canonical "already sent" check.
 *   2. `runStatusRefresh` — every 6 hours, flip UPCOMING events whose
 *      startsAt + 4h is in the past to COMPLETED so the ATTENDED RSVP
 *      gate (and P3.3 review prompt) becomes available.
 *
 * Multi-instance safety is enforced via a postgres advisory lock —
 * only the holder runs the body; everyone else short-circuits. Lock
 * IDs are arbitrary constants below 2^31.
 */
const ADVISORY_LOCK_REMINDER = 854_301;
const ADVISORY_LOCK_STATUS_REFRESH = 854_302;
const ADVISORY_LOCK_LIVE_ARCHIVE = 854_303;

const D1_WINDOW_MIN = 30;
const H1_WINDOW_MIN = 5;
const STATUS_COMPLETE_AFTER_HOURS = 4;
const TICK_EVENT_CAP = 100;

@Injectable()
export class EventReminderCron {
  private readonly log = new Logger(EventReminderCron.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly digest: EventDigestService,
    private readonly live: EventLiveService,
  ) {}

  // ---- Schedule wrappers (single instance via advisory lock) ----------

  @Cron(CronExpression.EVERY_HOUR)
  async hourlyTick(): Promise<void> {
    if (process.env.EVENT_REMINDER_ENABLED === '0') return;
    const got = await this._tryLock(ADVISORY_LOCK_REMINDER);
    if (!got) return;
    try {
      await this.runReminderTick(new Date());
    } catch (e) {
      this.log.warn(
        `reminder tick failed: ${e instanceof Error ? e.message : String(e)}`,
      );
    } finally {
      await this._unlock(ADVISORY_LOCK_REMINDER);
    }
  }

  @Cron('0 0 */6 * * *') // every 6 hours, on the hour
  async statusRefresh(): Promise<void> {
    if (process.env.EVENT_REMINDER_ENABLED === '0') return;
    const got = await this._tryLock(ADVISORY_LOCK_STATUS_REFRESH);
    if (!got) return;
    try {
      await this.runStatusRefresh(new Date());
    } catch (e) {
      this.log.warn(
        `status refresh failed: ${e instanceof Error ? e.message : String(e)}`,
      );
    } finally {
      await this._unlock(ADVISORY_LOCK_STATUS_REFRESH);
    }
  }

  /**
   * P6.8 archive sweep — twice a day is enough granularity given the
   * 48h horizon. Lazily mutates `archived_at` on event_live_posts whose
   * event passed `starts_at + 48h`. Archived rows still exist for
   * audit; they just disappear from the read API.
   */
  @Cron('0 30 */12 * * *')
  async liveArchive(): Promise<void> {
    if (process.env.EVENT_REMINDER_ENABLED === '0') return;
    const got = await this._tryLock(ADVISORY_LOCK_LIVE_ARCHIVE);
    if (!got) return;
    try {
      const { archived } = await this.live.archiveExpired();
      if (archived > 0) {
        this.log.log(`event live archive: marked ${archived} rows`);
      }
    } catch (e) {
      this.log.warn(
        `live archive failed: ${e instanceof Error ? e.message : String(e)}`,
      );
    } finally {
      await this._unlock(ADVISORY_LOCK_LIVE_ARCHIVE);
    }
  }

  // ---- Manual / ops --------------------------------------------------

  /**
   * Same body as the hourly cron, called from the ops controller. Does
   * NOT take the advisory lock — the operator triggered it explicitly,
   * and the unique `(event, user, kind)` constraint still prevents
   * double sends if it races with the cron tick.
   */
  async runReminderTick(now: Date): Promise<{
    d1: number;
    h1: number;
    review_prompt: number;
    recap_written: number;
  }> {
    let d1 = 0;
    let h1 = 0;
    let reviewPrompt = 0;
    let recapWritten = 0;

    // D-1 window: events starting now+24h ± 30min.
    const d1Start = new Date(
      now.getTime() + 24 * 60 * 60 * 1000 - D1_WINDOW_MIN * 60 * 1000,
    );
    const d1End = new Date(
      now.getTime() + 24 * 60 * 60 * 1000 + D1_WINDOW_MIN * 60 * 1000,
    );
    d1 = await this._fanoutKind('D1', d1Start, d1End);

    // H-1 window: events starting now+1h ± 5min.
    const h1Start = new Date(
      now.getTime() + 60 * 60 * 1000 - H1_WINDOW_MIN * 60 * 1000,
    );
    const h1End = new Date(
      now.getTime() + 60 * 60 * 1000 + H1_WINDOW_MIN * 60 * 1000,
    );
    h1 = await this._fanoutKind('H1', h1Start, h1End);

    // REVIEW_PROMPT: events whose startsAt + 24h is in the [now-30min,
    // now+30min] window. Target: ATTENDED RSVPs only.
    const rpStart = new Date(now.getTime() - 24 * 60 * 60 * 1000 - 30 * 60 * 1000);
    const rpEnd = new Date(now.getTime() - 24 * 60 * 60 * 1000 + 30 * 60 * 1000);
    reviewPrompt = await this._fanoutReviewPrompt(rpStart, rpEnd);

    // P3.5: generate post-event recap digests for events that crossed
    // their D+1 mark in the last hour. Idempotent upsert so a missed
    // tick re-publishes on the next run.
    try {
      const recap = await this.digest.generateDueRecaps(now);
      recapWritten = recap.written;
    } catch (e) {
      this.log.warn(
        `recap digest generation failed: ${e instanceof Error ? e.message : String(e)}`,
      );
    }

    return { d1, h1, review_prompt: reviewPrompt, recap_written: recapWritten };
  }

  async runStatusRefresh(now: Date): Promise<{ flipped: number }> {
    const cutoff = new Date(
      now.getTime() - STATUS_COMPLETE_AFTER_HOURS * 60 * 60 * 1000,
    );
    const res = await this.prisma.eventCard.updateMany({
      where: {
        eventStatus: 'UPCOMING',
        startsAt: { lt: cutoff },
      },
      data: { eventStatus: 'COMPLETED' },
    });
    return { flipped: res.count };
  }

  // ---- Internals -----------------------------------------------------

  private async _fanoutKind(
    kind: 'D1' | 'H1',
    windowStart: Date,
    windowEnd: Date,
  ): Promise<number> {
    const events = await this.prisma.eventCard.findMany({
      where: {
        startsAt: { gte: windowStart, lte: windowEnd },
        eventStatus: 'UPCOMING',
      },
      take: TICK_EVENT_CAP,
    });
    if (events.length === 0) return 0;

    let totalSent = 0;
    for (const ev of events) {
      const rsvps = await this.prisma.eventRsvp.findMany({
        where: {
          eventCardId: ev.id,
          status: { in: ['INTERESTED', 'GOING'] },
        },
        select: { userId: true },
      });
      for (const r of rsvps) {
        const sent = await this._tryRecordSend(ev.id, r.userId, kind);
        if (!sent) continue;
        await this.prisma.notification.create({
          data: {
            userId: r.userId,
            type: 'EVENT_REMINDER',
            payload: {
              eventCardId: ev.id,
              title: ev.title,
              startsAt: ev.startsAt.toISOString(),
              reminderKind: kind,
              spaceAccessPolicy: 'PUBLIC',
            },
          },
        });
        totalSent += 1;
      }
    }
    return totalSent;
  }

  private async _fanoutReviewPrompt(
    windowStart: Date,
    windowEnd: Date,
  ): Promise<number> {
    const events = await this.prisma.eventCard.findMany({
      where: {
        startsAt: { gte: windowStart, lte: windowEnd },
      },
      take: TICK_EVENT_CAP,
    });
    if (events.length === 0) return 0;
    let total = 0;
    for (const ev of events) {
      const rsvps = await this.prisma.eventRsvp.findMany({
        where: { eventCardId: ev.id, status: 'ATTENDED' },
        select: { userId: true },
      });
      for (const r of rsvps) {
        const sent = await this._tryRecordSend(ev.id, r.userId, 'REVIEW_PROMPT');
        if (!sent) continue;
        await this.prisma.notification.create({
          data: {
            userId: r.userId,
            type: 'REVIEW_PROMPT',
            payload: {
              eventCardId: ev.id,
              title: ev.title,
              spaceAccessPolicy: 'PUBLIC',
            },
          },
        });
        total += 1;
      }
    }
    return total;
  }

  /**
   * Returns true when the row was newly inserted (i.e., the caller now
   * "owns" the send); false on unique-constraint collision (already
   * sent by another tick / instance).
   */
  private async _tryRecordSend(
    eventCardId: string,
    userId: string,
    kind: string,
  ): Promise<boolean> {
    try {
      await this.prisma.eventReminderSend.create({
        data: { eventCardId, userId, reminderKind: kind },
      });
      return true;
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        return false;
      }
      throw e;
    }
  }

  private async _tryLock(lockId: number): Promise<boolean> {
    const rows = await this.prisma.$queryRaw<{ locked: boolean }[]>`
      SELECT pg_try_advisory_lock(${lockId}::bigint) AS locked
    `;
    return rows[0]?.locked === true;
  }

  private async _unlock(lockId: number): Promise<void> {
    await this.prisma.$queryRaw`
      SELECT pg_advisory_unlock(${lockId}::bigint)
    `;
  }
}
