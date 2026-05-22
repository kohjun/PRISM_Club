import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { NotificationService } from './notification.service';

const ADVISORY_LOCK_ID = 854_304;
const COOLDOWN_DAYS = 6;
const BATCH_SIZE = 200;
const SECTIONS_CAP = 8;

interface DigestSection {
  kind: 'CONTRIBUTION' | 'POST' | 'EVENT';
  hub_slug?: string;
  room_slug?: string;
  title: string;
  snippet?: string;
  count?: number;
  ref_id?: string;
}

interface DigestPayload {
  schemaVersion: 1;
  sections: DigestSection[];
  spaceAccessPolicy: 'PUBLIC';
}

/**
 * P4.6 weekly digest fan-out.
 *
 * Iterates users with `weekly_digest_enabled=true` and an opt-in older
 * than 6 days since the last digest. For each, collects:
 *   - approved knowledge contributions in their followed hubs (7d)
 *   - top engagement posts in their followed rooms (7d)
 *   - upcoming events linked to their followed hubs (next 7d)
 * Writes one Notification row of type='WEEKLY_DIGEST' and calls
 * `dispatchDelivery` so the push fan-out (if configured) reaches the
 * recipient's device.
 *
 * Multi-replica safe via `pg_try_advisory_lock(854304)`. Sunday 18:00
 * KST = Sun 09:00 UTC.
 */
@Injectable()
export class WeeklyDigestService {
  private readonly log = new Logger(WeeklyDigestService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationService,
  ) {}

  async run(now: Date = new Date()): Promise<{
    candidates: number;
    sent: number;
    skipped_empty: number;
    skipped_cooldown: number;
  }> {
    const got = await this._tryLock();
    if (!got) return { candidates: 0, sent: 0, skipped_empty: 0, skipped_cooldown: 0 };
    try {
      return await this._runBody(now);
    } finally {
      await this._unlock();
    }
  }

  private async _runBody(now: Date): Promise<{
    candidates: number;
    sent: number;
    skipped_empty: number;
    skipped_cooldown: number;
  }> {
    const cooldownCutoff = new Date(
      now.getTime() - COOLDOWN_DAYS * 24 * 60 * 60 * 1000,
    );
    const weekStart = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const futureWindowEnd = new Date(
      now.getTime() + 7 * 24 * 60 * 60 * 1000,
    );

    const prefs = await this.prisma.notificationPreference.findMany({
      where: {
        weeklyDigestEnabled: true,
        OR: [
          { weeklyDigestLastSentAt: null },
          { weeklyDigestLastSentAt: { lt: cooldownCutoff } },
        ],
      },
      select: { userId: true, weeklyDigestLastSentAt: true },
      take: BATCH_SIZE,
    });

    let sent = 0;
    let skippedEmpty = 0;
    let skippedCooldown = 0;
    for (const p of prefs) {
      // Belt-and-braces: re-check the cooldown inside the loop in
      // case another instance picked the same user.
      if (
        p.weeklyDigestLastSentAt &&
        p.weeklyDigestLastSentAt >= cooldownCutoff
      ) {
        skippedCooldown += 1;
        continue;
      }

      const sections = await this._sectionsFor(
        p.userId,
        weekStart,
        now,
        futureWindowEnd,
      );
      if (sections.length === 0) {
        skippedEmpty += 1;
        continue;
      }
      const payload: DigestPayload = {
        schemaVersion: 1,
        sections,
        spaceAccessPolicy: 'PUBLIC',
      };
      const notif = await this.prisma.notification.create({
        data: {
          userId: p.userId,
          type: 'WEEKLY_DIGEST',
          payload: payload as unknown as object,
        },
      });
      // Fire-and-forget downstream delivery (push / email layers).
      this.notifications.dispatchDelivery({
        notificationId: notif.id,
        userId: p.userId,
        type: 'WEEKLY_DIGEST',
        payload: payload as unknown as Record<string, unknown>,
      });
      // Stamp the cooldown anchor so cooldown logic survives partial
      // batches and restarts.
      await this.prisma.notificationPreference.update({
        where: { userId: p.userId },
        data: { weeklyDigestLastSentAt: now },
      });
      sent += 1;
    }
    return {
      candidates: prefs.length,
      sent,
      skipped_empty: skippedEmpty,
      skipped_cooldown: skippedCooldown,
    };
  }

  private async _sectionsFor(
    userId: string,
    weekStart: Date,
    now: Date,
    futureWindowEnd: Date,
  ): Promise<DigestSection[]> {
    // Pull followed rooms + their categories (hubs).
    const follows = await this.prisma.roomFollow.findMany({
      where: { userId },
      include: {
        room: { include: { category: { include: { topicHub: true } } } },
      },
    });
    if (follows.length === 0) return [];

    const roomIds = follows.map((f) => f.roomId);
    const categoryIds = [...new Set(follows.map((f) => f.room.categoryId))];
    const hubIds = follows
      .map((f) => f.room.category.topicHub?.id)
      .filter((x): x is string => Boolean(x));

    const [contribs, popularPosts, upcomingEvents] = await Promise.all([
      this.prisma.knowledgeContribution.findMany({
        where: {
          status: 'APPROVED',
          resolvedAt: { gte: weekStart, lt: now },
          topicHubId: { in: hubIds },
        },
        include: {
          hub: { include: { category: true } },
          contributor: { include: { profile: true } },
        },
        orderBy: { resolvedAt: 'desc' },
        take: 3,
      }),
      this.prisma.post.findMany({
        where: {
          roomId: { in: roomIds },
          status: 'VISIBLE',
          createdAt: { gte: weekStart, lt: now },
        },
        include: { room: true },
        orderBy: [
          { likeCount: 'desc' },
          { bookmarkCount: 'desc' },
          { replyCount: 'desc' },
        ],
        take: 3,
      }),
      this.prisma.eventCard.findMany({
        where: {
          eventStatus: 'UPCOMING',
          startsAt: { gte: now, lt: futureWindowEnd },
          topicHubLinks: { some: { hub: { categoryId: { in: categoryIds } } } },
        },
        orderBy: { startsAt: 'asc' },
        take: 3,
      }),
    ]);

    const sections: DigestSection[] = [];
    for (const c of contribs) {
      sections.push({
        kind: 'CONTRIBUTION',
        hub_slug: c.hub.category.slug,
        title: c.proposedTitle,
        snippet:
          c.contributor.profile?.nickname
            ? `${c.contributor.profile.nickname}님의 제안`
            : '새 제안',
        ref_id: c.id,
      });
    }
    for (const p of popularPosts) {
      sections.push({
        kind: 'POST',
        room_slug: p.room.slug,
        title: p.body.length > 60 ? `${p.body.slice(0, 60)}…` : p.body,
        count: p.likeCount + p.replyCount,
        ref_id: p.id,
      });
    }
    for (const e of upcomingEvents) {
      sections.push({
        kind: 'EVENT',
        title: e.title,
        snippet: `${e.region} · ${e.venueName}`,
        ref_id: e.id,
      });
    }
    return sections.slice(0, SECTIONS_CAP);
  }

  private async _tryLock(): Promise<boolean> {
    const rows = await this.prisma.$queryRaw<{ locked: boolean }[]>`
      SELECT pg_try_advisory_lock(${ADVISORY_LOCK_ID}::bigint) AS locked
    `;
    return rows[0]?.locked === true;
  }

  private async _unlock(): Promise<void> {
    await this.prisma.$queryRaw`
      SELECT pg_advisory_unlock(${ADVISORY_LOCK_ID}::bigint)
    `;
  }
}
