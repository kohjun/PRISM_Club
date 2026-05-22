import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import {
  AccessControlService,
  Viewer,
} from '../../shared/access-control.service';
import {
  DigestPayloadV1,
  DigestRefreshSummaryDTO,
  TopicHubDigestDTO,
} from './dto/digest.dto';

const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

/**
 * Topic Hub weekly digest generator (P2.4).
 *
 * Period windows are anchored on Asia/Seoul Mondays 00:00.
 * `generateForHub` is upsert-idempotent on (topicHubId, periodStart);
 * the ops endpoint runs `refreshAll` either on-demand (curator click)
 * or, later, on the P3.2 weekly cron (Mon 09:00 KST).
 *
 * "Empty" weeks (no revisions / new refs / new events / popular posts)
 * intentionally do NOT get a row. The API returns null and the mobile
 * section hides itself so a brand-new hub doesn't show an empty card.
 */
@Injectable()
export class DigestService {
  private readonly log = new Logger(DigestService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
  ) {}

  // ---- Read --------------------------------------------------------

  async getForCategory(
    categorySlug: string,
    viewer: Viewer,
    period: 'current' | 'previous' = 'current',
  ): Promise<TopicHubDigestDTO | null> {
    const category = await this.prisma.category.findUnique({
      where: { slug: categorySlug },
      include: { space: true, topicHub: true },
    });
    if (!category || !category.topicHub) {
      throw new NotFoundException(
        `Topic hub not found for category: ${categorySlug}`,
      );
    }
    if (
      !this.access
        .accessPoliciesAllowedFor(viewer)
        .includes(category.space.accessPolicy)
    ) {
      throw new NotFoundException(
        `Topic hub not found for category: ${categorySlug}`,
      );
    }

    const window =
      period === 'previous' ? this.previousWindow() : this.currentWindow();
    const row = await this.prisma.topicHubDigest.findUnique({
      where: {
        topicHubId_periodStart: {
          topicHubId: category.topicHub.id,
          periodStart: window.start,
        },
      },
    });
    if (!row) return null;
    return this.toDTO(row, category.slug);
  }

  // ---- Write -------------------------------------------------------

  async generateForHub(
    topicHubId: string,
    window?: { start: Date; end: Date },
  ): Promise<{ wrote: boolean; reason?: string }> {
    const w = window ?? this.currentWindow();
    const hub = await this.prisma.topicHub.findUnique({
      where: { id: topicHubId },
      include: { category: { include: { space: true } } },
    });
    if (!hub) {
      throw new NotFoundException(`Topic hub not found: ${topicHubId}`);
    }
    const spaceAccessPolicy = hub.category.space.accessPolicy;

    // 1. Revisions in this period for any block in this hub.
    const revisions = await this.prisma.knowledgeBlockRevision.findMany({
      where: {
        block: { topicHubId },
        changedAt: { gte: w.start, lt: w.end },
        source: { in: ['CONTRIBUTION', 'ADMIN'] },
      },
      orderBy: { changedAt: 'desc' },
      take: 10,
      include: {
        changedBy: { include: { profile: true } },
      },
    });

    // 2. New references linked to this hub in this period.
    const refLinks = await this.prisma.topicHubReferenceLink.findMany({
      where: { topicHubId },
      include: { reference: true },
    });
    const newReferences = refLinks
      .filter((rl) => rl.reference.createdAt >= w.start && rl.reference.createdAt < w.end)
      .filter((rl) => rl.reference.status !== 'HIDDEN' && rl.reference.status !== 'DELETED')
      .slice(0, 10)
      .map((rl) => rl.reference);

    // 3. New events linked to this hub starting in this period.
    const eventLinks = await this.prisma.topicHubEventLink.findMany({
      where: { topicHubId },
      include: { eventCard: true },
    });
    const newEvents = eventLinks
      .filter((el) => el.eventCard.startsAt >= w.start && el.eventCard.startsAt < w.end)
      .slice(0, 10)
      .map((el) => el.eventCard);

    // 4. Popular posts in any room under this hub's category, ordered
    //    by simple engagement = likeCount + bookmarkCount + replyCount.
    const popularPosts = await this.prisma.post.findMany({
      where: {
        room: { categoryId: hub.categoryId },
        status: 'VISIBLE',
        createdAt: { gte: w.start, lt: w.end },
      },
      include: { room: true },
      orderBy: [
        { likeCount: 'desc' },
        { bookmarkCount: 'desc' },
        { replyCount: 'desc' },
        { createdAt: 'desc' },
      ],
      take: 5,
    });

    const isEmpty =
      revisions.length === 0 &&
      newReferences.length === 0 &&
      newEvents.length === 0 &&
      popularPosts.length === 0;
    if (isEmpty) {
      return { wrote: false, reason: 'empty-week' };
    }

    const payload: DigestPayloadV1 = {
      schemaVersion: 1,
      spaceAccessPolicy,
      revisions: revisions.map((r) => ({
        block_id: r.blockId,
        version: r.version,
        block_type: r.blockType,
        title: r.title,
        contributor_nickname: r.changedBy?.profile?.nickname ?? null,
        changed_at: r.changedAt.toISOString(),
      })),
      newReferences: newReferences.map((r) => ({
        id: r.id,
        title: r.title,
        source_tier: r.sourceTier,
        source_name: r.sourceName,
        url: r.url,
      })),
      newEvents: newEvents.map((e) => ({
        id: e.id,
        title: e.title,
        venue_name: e.venueName,
        region: e.region,
        starts_at: e.startsAt.toISOString(),
        thumbnail_url: e.thumbnailUrl,
      })),
      popularPosts: popularPosts.map((p) => ({
        id: p.id,
        snippet: p.body.length > 120 ? `${p.body.slice(0, 120)}…` : p.body,
        room_slug: p.room.slug,
        like_count: p.likeCount,
        reply_count: p.replyCount,
      })),
    };

    await this.prisma.topicHubDigest.upsert({
      where: {
        topicHubId_periodStart: {
          topicHubId,
          periodStart: w.start,
        },
      },
      create: {
        topicHubId,
        periodStart: w.start,
        periodEnd: w.end,
        payload: payload as unknown as object,
      },
      update: {
        periodEnd: w.end,
        payload: payload as unknown as object,
        generatedAt: new Date(),
      },
    });
    return { wrote: true };
  }

  async refreshAll(
    period: 'current' | 'previous' = 'current',
  ): Promise<DigestRefreshSummaryDTO> {
    const window =
      period === 'previous' ? this.previousWindow() : this.currentWindow();
    const hubs = await this.prisma.topicHub.findMany({
      where: { status: 'PUBLISHED' },
      select: { id: true },
    });
    let digestsWritten = 0;
    let emptyHubs = 0;
    for (const hub of hubs) {
      try {
        const r = await this.generateForHub(hub.id, window);
        if (r.wrote) digestsWritten += 1;
        else emptyHubs += 1;
      } catch (e) {
        this.log.warn(
          `digest generation failed for hub=${hub.id}: ${e instanceof Error ? e.message : String(e)}`,
        );
      }
    }
    return {
      period_start: window.start.toISOString(),
      period_end: window.end.toISOString(),
      hubs_processed: hubs.length,
      digests_written: digestsWritten,
      empty_hubs: emptyHubs,
    };
  }

  // ---- Internals ---------------------------------------------------

  /**
   * Returns [Mon 00:00 KST, next-Mon 00:00 KST) of the week containing
   * `now`. The DB stores UTC; we compute the KST boundary then convert.
   */
  private currentWindow(): { start: Date; end: Date } {
    return this.weekBoundsFor(new Date());
  }

  private previousWindow(): { start: Date; end: Date } {
    const now = new Date();
    const previous = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    return this.weekBoundsFor(previous);
  }

  private weekBoundsFor(now: Date): { start: Date; end: Date } {
    const kstNow = new Date(now.getTime() + KST_OFFSET_MS);
    // getUTCDay returns 0..6 (Sun..Sat). We want Monday-anchored weeks:
    // shift so Sunday → 6 (rollover to previous Mon), Mon → 0.
    const dayMonAnchored = (kstNow.getUTCDay() + 6) % 7;
    const kstMidnight = new Date(
      Date.UTC(
        kstNow.getUTCFullYear(),
        kstNow.getUTCMonth(),
        kstNow.getUTCDate(),
      ),
    );
    const kstMonday = new Date(
      kstMidnight.getTime() - dayMonAnchored * 24 * 60 * 60 * 1000,
    );
    const startUtc = new Date(kstMonday.getTime() - KST_OFFSET_MS);
    const endUtc = new Date(startUtc.getTime() + 7 * 24 * 60 * 60 * 1000);
    return { start: startUtc, end: endUtc };
  }

  private toDTO(
    row: {
      topicHubId: string;
      periodStart: Date;
      periodEnd: Date;
      generatedAt: Date;
      payload: unknown;
    },
    categorySlug: string,
  ): TopicHubDigestDTO {
    const payload = row.payload as DigestPayloadV1;
    if (payload?.schemaVersion !== 1) {
      throw new BadRequestException('Unknown digest payload schema');
    }
    return {
      topic_hub_id: row.topicHubId,
      category_slug: categorySlug,
      period_start: row.periodStart.toISOString(),
      period_end: row.periodEnd.toISOString(),
      generated_at: row.generatedAt.toISOString(),
      payload,
    };
  }
}
