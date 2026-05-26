import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import {
  AccessControlService,
  Viewer,
} from '../../shared/access-control.service';
import { AnalyticsService } from '../analytics/analytics.service';

/**
 * P7.3 — Event recap auto-draft.
 *
 * `POST /v1/event-cards/:id/recap/suggest` returns an in-memory composer
 * prefill — body markdown, attachment hints, and a room shortlist —
 * synthesized from the data the existing P3.x services already capture
 * (EventReview, EventLivePost, EventRsvp, plus the EventDigestService
 * shape). The service does NOT persist a draft anywhere: when the user
 * hits publish the mobile composer goes through the normal
 * `POST /v1/rooms/:slug/posts` flow, so a recap is just a regular post
 * with the event card attached.
 *
 * Eligibility:
 *   - the event must be `COMPLETED` (recap of a future event makes no
 *     sense),
 *   - the viewer must either own one of the rooms linked through
 *     `TopicHubEventLink → hub → category → rooms[]`, OR be a verified
 *     planner / admin.
 *
 * Failure modes are explicit (404 unknown event, 400 not completed,
 * 403 not organizer-eligible) so the mobile CTA can show the right
 * copy without guessing.
 */
@Injectable()
export class EventRecapSuggestService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
    private readonly analytics: AnalyticsService,
  ) {}

  async suggestFor(
    eventCardId: string,
    viewer: Viewer & { id: string },
  ): Promise<RecapSuggestionDTO> {
    const event = await this.prisma.eventCard.findUnique({
      where: { id: eventCardId },
      include: {
        topicHubLinks: {
          include: {
            hub: {
              include: {
                category: { include: { rooms: true } },
              },
            },
          },
        },
      },
    });
    if (!event) {
      throw new NotFoundException(`Event not found: ${eventCardId}`);
    }
    if (event.eventStatus !== 'COMPLETED') {
      throw new BadRequestException(
        '완료된 이벤트만 후기 초안을 만들 수 있어요.',
      );
    }

    // Flatten linked rooms once — used by both the eligibility gate and
    // the suggested-room-slugs list. Duplicates are possible if a room is
    // reachable via more than one hub link, so dedupe by id.
    const linkedRoomMap = new Map<
      string,
      { id: string; slug: string; ownerId: string | null; status: string }
    >();
    for (const link of event.topicHubLinks) {
      for (const r of link.hub.category.rooms) {
        linkedRoomMap.set(r.id, {
          id: r.id,
          slug: r.slug,
          ownerId: r.ownerId,
          status: r.status,
        });
      }
    }
    const linkedRooms = [...linkedRoomMap.values()];

    const isPlanner = this.access.isVerifiedPlanner(viewer);
    const ownedRoomSlugs = linkedRooms
      .filter((r) => r.ownerId === viewer.id)
      .map((r) => r.slug);
    if (!isPlanner && ownedRoomSlugs.length === 0) {
      throw new ForbiddenException(
        '이 이벤트의 후기 초안은 연결된 방의 운영자 또는 검증된 기획자만 만들 수 있어요.',
      );
    }

    // Suggested room list: owned rooms first (the organizer's own surface),
    // then the other active linked rooms. Inactive rooms drop out so the
    // composer picker doesn't show stale targets.
    const ownedSet = new Set(ownedRoomSlugs);
    const otherActiveSlugs = linkedRooms
      .filter((r) => r.status === 'ACTIVE' && !ownedSet.has(r.slug))
      .map((r) => r.slug);
    const suggestedRoomSlugs = [...ownedRoomSlugs, ...otherActiveSlugs];

    // Pull the same signals the EventDigestService aggregates, plus the
    // live-post strip and RSVP counts the digest doesn't surface.
    const [
      topReviews,
      topLivePosts,
      reviewAgg,
      attendedCount,
      goingCount,
    ] = await Promise.all([
      this.prisma.eventReview.findMany({
        where: { eventCardId, status: 'VISIBLE' },
        orderBy: [{ rating: 'desc' }, { createdAt: 'desc' }],
        take: TOP_REVIEWS,
        include: { user: { include: { profile: true } } },
      }),
      this.prisma.eventLivePost.findMany({
        where: { eventCardId },
        orderBy: { createdAt: 'asc' },
        take: TOP_LIVE_POSTS,
        include: { author: { include: { profile: true } } },
      }),
      this.prisma.eventReview.aggregate({
        where: { eventCardId, status: 'VISIBLE' },
        _avg: { rating: true },
        _count: { _all: true },
      }),
      this.prisma.eventRsvp.count({
        where: { eventCardId, status: 'ATTENDED' },
      }),
      this.prisma.eventRsvp.count({
        where: { eventCardId, status: 'GOING' },
      }),
    ]);

    const body = buildSuggestedBody({
      title: event.title,
      startsAt: event.startsAt,
      venueName: event.venueName,
      region: event.region,
      attendedCount,
      goingCount,
      topReviews: topReviews.map((r) => ({
        rating: r.rating,
        snippet: clipSnippet(r.body),
        nickname: r.user?.profile?.nickname ?? '익명',
      })),
      topLivePosts: topLivePosts.map((p) => ({
        snippet: clipSnippet(p.body),
        nickname: p.author?.profile?.nickname ?? '익명',
      })),
      reviewCount: reviewAgg._count._all,
      averageRating: reviewAgg._avg.rating,
    });

    this.analytics.record({
      actorId: viewer.id,
      eventType: 'EVENT_RECAP_SUGGESTED',
      payload: {
        event_card_id: eventCardId,
        owned_room_count: ownedRoomSlugs.length,
        is_planner: isPlanner,
        review_count: reviewAgg._count._all ?? 0,
        live_post_count: topLivePosts.length,
        attended_count: attendedCount,
      },
    });

    return {
      event: {
        id: event.id,
        title: event.title,
        starts_at: event.startsAt.toISOString(),
        venue_name: event.venueName,
        region: event.region,
      },
      suggested_body: body,
      suggested_attachments: [
        { attachment_type: 'EVENT_CARD', target_id: event.id },
      ],
      suggested_room_slugs: suggestedRoomSlugs,
    };
  }
}

export interface RecapAttachmentSuggestion {
  attachment_type: 'EVENT_CARD';
  target_id: string;
}

export interface RecapSuggestionDTO {
  event: {
    id: string;
    title: string;
    starts_at: string;
    venue_name: string;
    region: string;
  };
  suggested_body: string;
  suggested_attachments: RecapAttachmentSuggestion[];
  suggested_room_slugs: string[];
}

const TOP_REVIEWS = 3;
const TOP_LIVE_POSTS = 3;
const SNIPPET_LEN = 120;

function clipSnippet(body: string): string {
  const trimmed = body.replace(/\s+/g, ' ').trim();
  if (trimmed.length <= SNIPPET_LEN) return trimmed;
  return `${trimmed.slice(0, SNIPPET_LEN)}…`;
}

interface BuildBodyInput {
  title: string;
  startsAt: Date;
  venueName: string;
  region: string;
  attendedCount: number;
  goingCount: number;
  topReviews: Array<{ rating: number; snippet: string; nickname: string }>;
  topLivePosts: Array<{ snippet: string; nickname: string }>;
  reviewCount: number;
  averageRating: number | null;
}

function formatKst(date: Date): string {
  // Intl is the cheapest deterministic Korean formatter that's already
  // available in Node 18+. Avoiding dayjs/luxon keeps the dep surface
  // flat — this is the only place in the recap flow that touches dates.
  return new Intl.DateTimeFormat('ko-KR', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(date);
}

function buildSuggestedBody(input: BuildBodyInput): string {
  const lines: string[] = [];
  lines.push(`## ${input.title} 후기`);
  lines.push('');
  lines.push(
    `📅 ${formatKst(input.startsAt)} · 📍 ${input.venueName}, ${input.region}`,
  );

  if (input.attendedCount > 0 || input.goingCount > 0) {
    const segments: string[] = [];
    if (input.attendedCount > 0) {
      segments.push(`참석 ${input.attendedCount}명`);
    }
    if (input.goingCount > 0) {
      segments.push(`참여 의향 ${input.goingCount}명`);
    }
    lines.push('');
    lines.push(`👥 ${segments.join(' · ')}`);
  }

  if (input.topReviews.length > 0) {
    lines.push('');
    lines.push('### 가장 많이 공감받은 후기 ⭐');
    for (const r of input.topReviews) {
      lines.push(`- ★${r.rating} "${r.snippet}" — ${r.nickname}`);
    }
  }

  if (input.topLivePosts.length > 0) {
    lines.push('');
    lines.push('### 현장에서 가장 활발했던 한 마디 🎤');
    for (const p of input.topLivePosts) {
      lines.push(`- "${p.snippet}" — @${p.nickname}`);
    }
  }

  if (input.averageRating !== null && input.reviewCount > 0) {
    lines.push('');
    lines.push('### 이번 이벤트 평균 평점');
    lines.push(
      `★${input.averageRating.toFixed(1)}/5 (리뷰 ${input.reviewCount}건)`,
    );
  }

  // Empty-event fallback so the user still has something to start from.
  // We don't 404 — an organizer wanting to write a recap from scratch
  // is still a valid path.
  if (
    input.topReviews.length === 0 &&
    input.topLivePosts.length === 0 &&
    input.attendedCount === 0 &&
    input.goingCount === 0
  ) {
    lines.push('');
    lines.push(
      '아직 이번 이벤트에 후기나 라이브 글이 없네요. 직접 본 만큼 적어주시면 좋아요.',
    );
  }

  lines.push('');
  lines.push('---');
  lines.push('> 이 초안은 자동 생성됐어요. 자유롭게 다듬어서 올려주세요.');

  return lines.join('\n');
}
