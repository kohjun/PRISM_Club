import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { CategoryService } from '../community/category.service';
import { RoomService } from '../community/room.service';

@Injectable()
export class KnowledgeService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly categories: CategoryService,
    private readonly rooms: RoomService,
  ) {}

  async getHubByCategorySlug(categorySlug: string) {
    const category = await this.categories.findBySlug(categorySlug);

    const hub = await this.prisma.topicHub.findUnique({
      where: { categoryId: category.id },
      include: {
        blocks: { orderBy: { sortOrder: 'asc' } },
        signals: { orderBy: { calculatedAt: 'desc' } },
        eventLinks: {
          include: { eventCard: true },
          orderBy: { sortOrder: 'asc' },
        },
        refLinks: {
          include: { reference: true },
          orderBy: { sortOrder: 'asc' },
        },
      },
    });

    const rooms = await this.rooms.listByCategorySlug(categorySlug);

    return {
      category: {
        id: category.id,
        slug: category.slug,
        name: category.name,
        description: category.description,
      },
      hub: hub
        ? {
            id: hub.id,
            title: hub.title,
            summary: hub.summary,
            updated_at: hub.updatedAt.toISOString(),
          }
        : null,
      blocks: hub
        ? hub.blocks.map((b) => ({
            id: b.id,
            block_type: b.blockType,
            title: b.title,
            body: b.body,
            sort_order: b.sortOrder,
          }))
        : [],
      signals: hub
        ? hub.signals.map((s) => ({
            id: s.id,
            signal_type: s.signalType,
            title: s.title,
            payload: s.payload,
            calculated_at: s.calculatedAt.toISOString(),
          }))
        : [],
      related_events: hub
        ? hub.eventLinks.map((link) => this.rooms.toEventCardDTO(link.eventCard))
        : [],
      related_references: hub
        ? hub.refLinks.map((link) => this.rooms.toReferenceDTO(link.reference))
        : [],
      rooms,
    };
  }
}
