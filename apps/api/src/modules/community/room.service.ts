import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService, Viewer } from '../../shared/access-control.service';
import { CategoryService } from './category.service';
import { EventCardDTO, PinDTO, ReferenceDTO, RoomDetailDTO, RoomSummaryDTO } from './dto/room.dto';

export interface CreateUserRoomInput {
  name: string;
  description?: string;
  room_type: string;
  tags?: string[];
  pinned_event_card_id?: string;
  pinned_reference_id?: string;
}

const ALLOWED_USER_ROOM_TYPES = new Set([
  'DISCUSSION',
  'EVENT_REACTION',
  'REFERENCE',
  'IDEA',
  'RECRUITMENT',
  'SOCIAL',
]);

@Injectable()
export class RoomService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
    private readonly categories: CategoryService,
  ) {}

  // -- Reads ---------------------------------------------------------------

  async listByCategorySlug(
    categorySlug: string,
    viewer: Viewer,
  ): Promise<RoomSummaryDTO[]> {
    await this.access.assertCanReadCategoryBySlug(categorySlug, viewer);

    const category = await this.categories.findBySlug(categorySlug);
    const rooms = await this.prisma.room.findMany({
      where: { categoryId: category.id, status: 'ACTIVE' },
      include: { owner: { include: { profile: true } } },
      orderBy: [{ origin: 'asc' }, { name: 'asc' }],
    });
    return rooms.map((r) => this.toSummary(r));
  }

  async getRoomDetailBySlug(slug: string, viewer: Viewer): Promise<RoomDetailDTO> {
    await this.access.assertCanReadRoomBySlug(slug, viewer);

    const room = await this.prisma.room.findUnique({
      where: { slug },
      include: {
        owner: { include: { profile: true } },
        pins: true,
        _count: { select: { posts: true } },
      },
    });
    if (!room || room.status !== 'ACTIVE') {
      throw new NotFoundException(`Room not found: ${slug}`);
    }

    const pins = await this.resolvePins(room.pins);
    const summary = this.toSummary(room);

    return {
      ...summary,
      rules: room.rules,
      owner: room.owner
        ? { id: room.owner.id, nickname: room.owner.profile?.nickname ?? '' }
        : null,
      pins,
      counts: { post_count: room._count.posts },
    };
  }

  /**
   * Access-naive lookup used by other services (e.g., PostService) after they
   * have already gated the request via AccessControlService.
   */
  async getRoomBySlug(slug: string) {
    const room = await this.prisma.room.findUnique({ where: { slug } });
    if (!room || room.status !== 'ACTIVE') {
      throw new NotFoundException(`Room not found: ${slug}`);
    }
    return room;
  }

  // -- Create user room ----------------------------------------------------

  async createUserRoom(
    categorySlug: string,
    input: CreateUserRoomInput,
    userId: string,
    viewer: Viewer,
  ): Promise<RoomDetailDTO> {
    await this.access.assertCanReadCategoryBySlug(categorySlug, viewer);

    const category = await this.categories.findBySlug(categorySlug);

    if (!ALLOWED_USER_ROOM_TYPES.has(input.room_type)) {
      throw new NotFoundException(`Invalid room_type: ${input.room_type}`);
    }

    // Validate pin targets exist before opening a transaction
    if (input.pinned_event_card_id) {
      const ec = await this.prisma.eventCard.findUnique({
        where: { id: input.pinned_event_card_id },
      });
      if (!ec) throw new NotFoundException('pinned_event_card_id not found');
    }
    if (input.pinned_reference_id) {
      const ref = await this.prisma.reference.findUnique({
        where: { id: input.pinned_reference_id },
      });
      if (!ref) throw new NotFoundException('pinned_reference_id not found');
    }

    const slug = await this.uniqueSlugFor(input.name);

    const room = await this.prisma.$transaction(async (tx) => {
      const created = await tx.room.create({
        data: {
          categoryId: category.id,
          ownerId: userId,
          slug,
          name: input.name,
          description: input.description ?? null,
          origin: 'USER',
          roomType: input.room_type,
          tags: input.tags ?? [],
        },
      });

      const pinRows: Prisma.RoomPinCreateManyInput[] = [];
      if (input.pinned_event_card_id) {
        pinRows.push({
          roomId: created.id,
          targetType: 'EVENT_CARD',
          targetId: input.pinned_event_card_id,
          sortOrder: 1,
        });
      }
      if (input.pinned_reference_id) {
        pinRows.push({
          roomId: created.id,
          targetType: 'REFERENCE',
          targetId: input.pinned_reference_id,
          sortOrder: pinRows.length + 1,
        });
      }
      if (pinRows.length > 0) {
        await tx.roomPin.createMany({ data: pinRows });
      }

      return created;
    });

    return this.getRoomDetailBySlug(room.slug, viewer);
  }

  private async uniqueSlugFor(name: string): Promise<string> {
    const base = this.slugify(name);
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const candidate = attempt === 0 ? base : `${base}-${this.shortHash()}`;
      const existing = await this.prisma.room.findUnique({ where: { slug: candidate } });
      if (!existing) return candidate;
    }
    throw new ConflictException('Could not generate a unique room slug, please retry');
  }

  private slugify(name: string): string {
    const stripped = name
      .normalize('NFKD')
      .toLowerCase()
      .replace(/[^a-z0-9가-힣\s-]/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-')
      .replace(/^-|-$/g, '');
    if (stripped.length > 0) return stripped;
    // Korean-only or empty after stripping → fall back to a short hash so the slug is URL-safe ASCII
    return `room-${this.shortHash()}`;
  }

  private shortHash(): string {
    return randomBytes(3).toString('hex'); // 6 hex chars
  }

  // -- Pin resolution ------------------------------------------------------

  async resolvePins(
    pinRows: Array<{
      id: string;
      targetType: string;
      targetId: string;
      sortOrder: number;
    }>,
  ): Promise<PinDTO[]> {
    if (pinRows.length === 0) return [];

    const eventIds = pinRows.filter((p) => p.targetType === 'EVENT_CARD').map((p) => p.targetId);
    const refIds = pinRows.filter((p) => p.targetType === 'REFERENCE').map((p) => p.targetId);

    const [events, references] = await Promise.all([
      eventIds.length > 0
        ? this.prisma.eventCard.findMany({ where: { id: { in: eventIds } } })
        : Promise.resolve([]),
      refIds.length > 0
        ? this.prisma.reference.findMany({ where: { id: { in: refIds } } })
        : Promise.resolve([]),
    ]);

    const eventMap = new Map(events.map((e) => [e.id, e]));
    const refMap = new Map(references.map((r) => [r.id, r]));

    return pinRows
      .map((p): PinDTO | null => {
        if (p.targetType === 'EVENT_CARD') {
          const e = eventMap.get(p.targetId);
          if (!e) return null;
          return {
            id: p.id,
            target_type: 'EVENT_CARD',
            sort_order: p.sortOrder,
            target: this.toEventCardDTO(e),
          };
        }
        if (p.targetType === 'REFERENCE') {
          const r = refMap.get(p.targetId);
          if (!r) return null;
          return {
            id: p.id,
            target_type: 'REFERENCE',
            sort_order: p.sortOrder,
            target: this.toReferenceDTO(r),
          };
        }
        return null;
      })
      .filter((p): p is PinDTO => p !== null)
      .sort((a, b) => a.sort_order - b.sort_order);
  }

  // -- DTO conversion ------------------------------------------------------

  private toSummary(room: any): RoomSummaryDTO {
    return {
      id: room.id,
      slug: room.slug,
      name: room.name,
      description: room.description,
      origin: room.origin,
      room_type: room.roomType,
      owner_nickname: room.owner?.profile?.nickname ?? null,
    };
  }

  toEventCardDTO(e: {
    id: string;
    externalEventId: string;
    title: string;
    venueName: string;
    region: string;
    startsAt: Date;
    eventStatus: string;
    thumbnailUrl: string | null;
  }): EventCardDTO {
    return {
      id: e.id,
      external_event_id: e.externalEventId,
      title: e.title,
      venue_name: e.venueName,
      region: e.region,
      starts_at: e.startsAt.toISOString(),
      event_status: e.eventStatus,
      thumbnail_url: e.thumbnailUrl,
    };
  }

  toReferenceDTO(r: {
    id: string;
    type: string;
    url: string;
    title: string;
    sourceName: string | null;
    thumbnailUrl: string | null;
    summary: string | null;
    status: string;
    sourceTier?: string;
  }): ReferenceDTO {
    return {
      id: r.id,
      type: r.type,
      url: r.url,
      title: r.title,
      source_name: r.sourceName,
      thumbnail_url: r.thumbnailUrl,
      summary: r.summary,
      status: r.status,
      source_tier: r.sourceTier ?? 'UNKNOWN',
    };
  }
}
