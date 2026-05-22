import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService, Viewer } from '../../shared/access-control.service';
import { AnalyticsService } from '../analytics/analytics.service';
import { MetricsService } from '../../shared/metrics.service';
import {
  SEARCH_TYPES,
  SearchEntityType,
  SearchGroupDTO,
  SearchHitDTO,
  SearchResponseDTO,
} from './dto/search.dto';

const DEFAULT_LIMIT = 10;
const MAX_LIMIT = 20;
const SNIPPET_RADIUS = 80;

const DEFAULT_SUGGESTIONS = [
  '환승연애',
  '소개팅 미션',
  '팀 미션',
  '예능 레퍼런스',
  '체크리스트',
  '분위기 팁',
  'FAQ',
];

// Per-category override map. Falls through to DEFAULT_SUGGESTIONS for
// unknown / null categorySlug. Tuned to what the seeded corpus surfaces.
const CATEGORY_SUGGESTIONS: Record<string, string[]> = {
  'love-content': [
    '환승연애',
    '소개팅 미션',
    '팀 미션',
    '선택 룸',
    '체크리스트',
    '분위기 팁',
    'FAQ',
  ],
  'planner-staff': [
    '스태프',
    '음향',
    '진행',
    '소개팅',
    '운영 체크리스트',
    '환승연애',
  ],
};

@Injectable()
export class SearchService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
    private readonly analytics: AnalyticsService,
    private readonly metrics: MetricsService,
  ) {}

  // -- /v1/search ---------------------------------------------------------

  async searchAll(
    rawQuery: string,
    types: SearchEntityType[] | null,
    limit: number | undefined,
    viewer: Viewer,
  ): Promise<SearchResponseDTO> {
    const q = rawQuery.trim();
    if (q.length === 0) {
      throw new BadRequestException('q must be a non-empty string');
    }
    if (q.length > 200) {
      throw new BadRequestException('q must be at most 200 characters');
    }
    const cap = Math.max(1, Math.min(limit ?? DEFAULT_LIMIT, MAX_LIMIT));
    const allowed = this.access.accessPoliciesAllowedFor(viewer);

    // The effective type set: passed-in subset or all known types. Order is
    // preserved by the SEARCH_TYPES array so the response groups are stable.
    const requested = new Set(types && types.length > 0 ? types : SEARCH_TYPES);

    const tasks: Promise<SearchGroupDTO>[] = SEARCH_TYPES.map(async (type) => {
      if (!requested.has(type)) {
        return { type, items: [] };
      }
      const items = await this.searchOne(type, q, cap, allowed);
      return { type, items };
    });

    const startedAt = Date.now();
    const groups = await Promise.all(tasks);
    const elapsedMs = Date.now() - startedAt;

    // P2.5: capture query telemetry. q itself goes through the
    // analytics payload scrubber (truncated to 120 chars; no PII keys),
    // so storing the literal text is intentionally safe for a search
    // query and useful for tracking zero-result terms.
    const totalHits = groups.reduce((sum, g) => sum + g.items.length, 0);
    this.analytics.record({
      eventType: 'SEARCH_QUERY',
      payload: {
        query: q,
        types_count: groups.length,
        total_hits: totalHits,
        zero_result: totalHits === 0,
        ms_elapsed: elapsedMs,
      },
    });
    // F5: surface latency to the system-health dashboard.
    this.metrics.record('search.latency_ms', elapsedMs);
    if (totalHits === 0) this.metrics.inc('search.zero_result');

    return { query: q, groups };
  }

  // -- /v1/search/suggestions --------------------------------------------

  suggestionsFor(categorySlug?: string | null): { items: string[] } {
    if (categorySlug && CATEGORY_SUGGESTIONS[categorySlug]) {
      return { items: CATEGORY_SUGGESTIONS[categorySlug] };
    }
    return { items: DEFAULT_SUGGESTIONS };
  }

  // -- per-entity helpers ------------------------------------------------

  private async searchOne(
    type: SearchEntityType,
    q: string,
    limit: number,
    allowed: string[],
  ): Promise<SearchHitDTO[]> {
    switch (type) {
      case 'topic_hub':
        return this.searchTopicHubs(q, limit, allowed);
      case 'knowledge_block':
        return this.searchKnowledgeBlocks(q, limit, allowed);
      case 'room':
        return this.searchRooms(q, limit, allowed);
      case 'post':
        return this.searchPosts(q, limit, allowed);
      case 'event_card':
        return this.searchEventCards(q, limit);
      case 'reference':
        return this.searchReferences(q, limit);
    }
  }

  private async searchTopicHubs(
    q: string,
    limit: number,
    allowed: string[],
  ): Promise<SearchHitDTO[]> {
    const rows = await this.prisma.topicHub.findMany({
      where: {
        OR: [
          { title: { contains: q, mode: 'insensitive' } },
          { summary: { contains: q, mode: 'insensitive' } },
        ],
        status: 'PUBLISHED',
        category: { space: { accessPolicy: { in: allowed } } },
      },
      include: { category: true },
      orderBy: { updatedAt: 'desc' },
      take: limit,
    });
    return rows.map((r) => ({
      type: 'topic_hub' as const,
      id: r.id,
      title: r.title,
      snippet: this.snippet(r.summary, q),
      context: { category_slug: r.category.slug },
    }));
  }

  private async searchKnowledgeBlocks(
    q: string,
    limit: number,
    allowed: string[],
  ): Promise<SearchHitDTO[]> {
    const rows = await this.prisma.knowledgeBlock.findMany({
      where: {
        OR: [
          { title: { contains: q, mode: 'insensitive' } },
          { body: { contains: q, mode: 'insensitive' } },
          { blockType: { contains: q, mode: 'insensitive' } },
        ],
        status: 'PUBLISHED',
        hub: { category: { space: { accessPolicy: { in: allowed } } } },
      },
      include: { hub: { include: { category: true } } },
      orderBy: { updatedAt: 'desc' },
      take: limit,
    });
    return rows.map((r) => ({
      type: 'knowledge_block' as const,
      id: r.id,
      title: r.title,
      snippet: this.snippet(r.body, q),
      context: {
        category_slug: r.hub.category.slug,
        block_type: r.blockType,
      },
    }));
  }

  private async searchRooms(
    q: string,
    limit: number,
    allowed: string[],
  ): Promise<SearchHitDTO[]> {
    const rows = await this.prisma.room.findMany({
      where: {
        OR: [
          { name: { contains: q, mode: 'insensitive' } },
          { description: { contains: q, mode: 'insensitive' } },
        ],
        status: 'ACTIVE',
        category: { space: { accessPolicy: { in: allowed } } },
      },
      include: {
        category: true,
        owner: { include: { profile: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
    return rows.map((r) => ({
      type: 'room' as const,
      id: r.id,
      title: r.name,
      snippet: this.snippet(r.description ?? '', q),
      context: {
        room_slug: r.slug,
        category_slug: r.category.slug,
        origin: r.origin,
        owner_nickname: r.owner?.profile?.nickname ?? null,
      },
    }));
  }

  private async searchPosts(
    q: string,
    limit: number,
    allowed: string[],
  ): Promise<SearchHitDTO[]> {
    const rows = await this.prisma.post.findMany({
      where: {
        body: { contains: q, mode: 'insensitive' },
        status: { notIn: ['DELETED', 'HIDDEN'] },
        room: { category: { space: { accessPolicy: { in: allowed } } } },
      },
      include: {
        room: true,
        author: { include: { profile: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
    return rows.map((r) => ({
      type: 'post' as const,
      id: r.id,
      title: this.firstLine(r.body, 60),
      snippet: this.snippet(r.body, q),
      context: {
        post_id: r.id,
        room_slug: r.room.slug,
        room_name: r.room.name,
        author_nickname: r.author.profile?.nickname ?? '',
      },
    }));
  }

  private async searchEventCards(q: string, limit: number): Promise<SearchHitDTO[]> {
    const rows = await this.prisma.eventCard.findMany({
      where: {
        OR: [
          { title: { contains: q, mode: 'insensitive' } },
          { venueName: { contains: q, mode: 'insensitive' } },
          { region: { contains: q, mode: 'insensitive' } },
        ],
      },
      orderBy: { startsAt: 'desc' },
      take: limit,
    });
    return rows.map((r) => ({
      type: 'event_card' as const,
      id: r.id,
      title: r.title,
      snippet: this.snippet(`${r.venueName} · ${r.region}`, q),
      context: {
        external_event_id: r.externalEventId,
        venue_name: r.venueName,
        region: r.region,
        starts_at: r.startsAt.toISOString(),
        event_status: r.eventStatus,
      },
    }));
  }

  private async searchReferences(q: string, limit: number): Promise<SearchHitDTO[]> {
    const rows = await this.prisma.reference.findMany({
      where: {
        OR: [
          { title: { contains: q, mode: 'insensitive' } },
          { sourceName: { contains: q, mode: 'insensitive' } },
          { summary: { contains: q, mode: 'insensitive' } },
          { url: { contains: q, mode: 'insensitive' } },
        ],
        status: 'VISIBLE',
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
    return rows.map((r) => ({
      type: 'reference' as const,
      id: r.id,
      title: r.title,
      snippet: this.snippet(r.summary ?? r.sourceName ?? r.url, q),
      context: {
        reference_type: r.type,
        url: r.url,
        source_name: r.sourceName,
      },
    }));
  }

  // -- helpers -----------------------------------------------------------

  /** Return a ~radius-char window of `body` centered on the first match of `q`. */
  snippet(body: string, q: string, radius: number = SNIPPET_RADIUS): string {
    if (!body) return '';
    const idx = body.toLowerCase().indexOf(q.toLowerCase());
    if (idx < 0) {
      return body.length > radius ? body.slice(0, radius) + '…' : body;
    }
    const halfBefore = Math.floor(radius / 2);
    const start = Math.max(0, idx - halfBefore);
    const end = Math.min(body.length, start + radius);
    return (
      (start > 0 ? '…' : '') +
      body.slice(start, end) +
      (end < body.length ? '…' : '')
    );
  }

  private firstLine(body: string, max: number): string {
    if (!body) return '';
    const eol = body.indexOf('\n');
    const head = eol >= 0 ? body.slice(0, eol) : body;
    return head.length > max ? head.slice(0, max) + '…' : head;
  }
}
