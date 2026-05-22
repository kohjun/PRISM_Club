import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AnalyticsService } from '../analytics/analytics.service';

const BODY_MAX = 500;
// "현장 라이브" write window after the event starts.
const IN_PROGRESS_HOURS = 4;
// Archive horizon — rows older than this drop out of the read API
// and into "archived" status via the cron.
const ARCHIVE_HOURS = 48;

export interface EventLiveAuthorDTO {
  id: string;
  nickname: string;
  avatar_url: string | null;
}

export interface EventLivePostDTO {
  id: string;
  body: string;
  image: {
    id: string;
    cdn_url: string | null;
    width: number | null;
    height: number | null;
  } | null;
  author: EventLiveAuthorDTO;
  created_at: string;
}

/**
 * P6.8 — Event "현장 라이브".
 *
 * Short-form posts attached to an EventCard, write-gated to the
 * IN_PROGRESS window AND to viewers whose RSVP=ATTENDED. The read
 * surface is also RSVP-gated (ATTENDED or GOING) so the strip stays
 * a closed-loop "you had to be there" feed.
 *
 * After 48h the cron sets `archived_at`. Archived rows survive in the
 * DB for audit but disappear from the read API.
 */
@Injectable()
export class EventLiveService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly analytics: AnalyticsService,
  ) {}

  async createLivePost(
    eventCardId: string,
    body: string,
    authorId: string,
    imageMediaId: string | null,
  ): Promise<EventLivePostDTO> {
    const trimmed = (body ?? '').trim();
    if (trimmed.length === 0 || trimmed.length > BODY_MAX) {
      throw new BadRequestException(`body must be 1..${BODY_MAX} chars`);
    }

    const card = await this.prisma.eventCard.findUnique({
      where: { id: eventCardId },
      select: { id: true, startsAt: true, title: true },
    });
    if (!card) throw new NotFoundException(`Event not found: ${eventCardId}`);

    const now = Date.now();
    const start = card.startsAt.getTime();
    const inProgressEnd = start + IN_PROGRESS_HOURS * 60 * 60 * 1000;
    if (now < start) {
      throw new BadRequestException('이벤트 시작 전에는 라이브를 올릴 수 없어요.');
    }
    if (now > inProgressEnd) {
      throw new BadRequestException(
        '이벤트 라이브 기간이 끝났어요 (시작 +4시간).',
      );
    }

    const rsvp = await this.prisma.eventRsvp.findUnique({
      where: { eventCardId_userId: { eventCardId, userId: authorId } },
      select: { status: true },
    });
    if (!rsvp || rsvp.status !== 'ATTENDED') {
      throw new ForbiddenException(
        'ATTENDED 상태의 RSVP가 있는 사용자만 라이브를 올릴 수 있어요.',
      );
    }

    if (imageMediaId) {
      const media = await this.prisma.mediaAsset.findUnique({
        where: { id: imageMediaId },
        select: { id: true, ownerId: true },
      });
      if (!media || media.ownerId !== authorId) {
        throw new NotFoundException('image_media_id not found or not yours');
      }
    }

    const row = await this.prisma.eventLivePost.create({
      data: {
        eventCardId,
        authorId,
        body: trimmed,
        imageMediaId,
      },
      include: {
        author: { include: { profile: true } },
        image: true,
      },
    });

    this.analytics.record({
      actorId: authorId,
      eventType: 'EVENT_LIVE_POSTED',
      payload: {
        event_card_id: eventCardId,
        has_image: imageMediaId !== null,
      },
    });

    return this.toDTO(row);
  }

  /**
   * Read the active "현장 라이브" strip. Only callers whose RSVP is
   * ATTENDED or GOING see entries — fresh anonymous visitors get an
   * empty list to keep the strip a closed-loop "you had to be there"
   * experience.
   */
  async listLivePosts(
    eventCardId: string,
    viewerId: string,
  ): Promise<EventLivePostDTO[]> {
    const card = await this.prisma.eventCard.findUnique({
      where: { id: eventCardId },
      select: { id: true },
    });
    if (!card) throw new NotFoundException(`Event not found: ${eventCardId}`);

    const rsvp = await this.prisma.eventRsvp.findUnique({
      where: { eventCardId_userId: { eventCardId, userId: viewerId } },
      select: { status: true },
    });
    const isInsider =
      rsvp && (rsvp.status === 'ATTENDED' || rsvp.status === 'GOING');
    if (!isInsider) return [];

    const rows = await this.prisma.eventLivePost.findMany({
      where: { eventCardId, archivedAt: null },
      include: {
        author: { include: { profile: true } },
        image: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 40,
    });
    return rows.map((r) => this.toDTO(r));
  }

  /**
   * Cron-driven archive sweep. Marks any non-archived live posts whose
   * event passed `starts_at + ARCHIVE_HOURS`. Returns the row count
   * so the cron caller can log it.
   */
  async archiveExpired(): Promise<{ archived: number }> {
    const cutoff = new Date(Date.now() - ARCHIVE_HOURS * 60 * 60 * 1000);
    const result = await this.prisma.eventLivePost.updateMany({
      where: {
        archivedAt: null,
        eventCard: { startsAt: { lt: cutoff } },
      },
      data: { archivedAt: new Date() },
    });
    return { archived: result.count };
  }

  private toDTO(row: {
    id: string;
    body: string;
    createdAt: Date;
    author: {
      id: string;
      profile: { nickname: string; avatarUrl: string | null } | null;
    };
    image: {
      id: string;
      cdnUrl: string | null;
      width: number | null;
      height: number | null;
    } | null;
  }): EventLivePostDTO {
    return {
      id: row.id,
      body: row.body,
      image: row.image
        ? {
            id: row.image.id,
            cdn_url: row.image.cdnUrl,
            width: row.image.width,
            height: row.image.height,
          }
        : null,
      author: {
        id: row.author.id,
        nickname: row.author.profile?.nickname ?? '',
        avatar_url: row.author.profile?.avatarUrl ?? null,
      },
      created_at: row.createdAt.toISOString(),
    };
  }
}
