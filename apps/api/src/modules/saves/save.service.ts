import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService, Viewer } from '../../shared/access-control.service';

const VALID_TYPES = ['POST', 'REFERENCE', 'EVENT_CARD'] as const;
type SaveTargetType = (typeof VALID_TYPES)[number];

export interface ToggleSaveInput {
  target_type: string;
  target_id: string;
}

export interface SaveToggleDTO {
  saved: boolean;
}

export interface SavedItemDTO {
  id: string;
  target_type: SaveTargetType;
  target_id: string;
  saved_at: string;
  target: Record<string, unknown>;
}

export interface SavedItemListDTO {
  items: SavedItemDTO[];
}

@Injectable()
export class SaveService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
  ) {}

  async toggle(input: ToggleSaveInput, viewer: Viewer & { id: string }): Promise<SaveToggleDTO> {
    const type = input.target_type as SaveTargetType;
    if (!VALID_TYPES.includes(type)) {
      throw new BadRequestException(`Invalid target_type: ${input.target_type}`);
    }

    const existing = await this.prisma.savedItem.findUnique({
      where: {
        userId_targetType_targetId: {
          userId: viewer.id,
          targetType: type,
          targetId: input.target_id,
        },
      },
    });

    if (existing) {
      await this.prisma.$transaction(async (tx) => {
        await tx.savedItem.delete({ where: { id: existing.id } });
        if (type === 'POST') {
          await tx.post.updateMany({
            where: { id: input.target_id, bookmarkCount: { gt: 0 } },
            data: { bookmarkCount: { decrement: 1 } },
          });
        }
      });
      return { saved: false };
    }

    // Validate target exists
    await this.assertTargetExists(type, input.target_id);

    await this.prisma.$transaction(async (tx) => {
      await tx.savedItem.create({
        data: { userId: viewer.id, targetType: type, targetId: input.target_id },
      });
      if (type === 'POST') {
        await tx.post.update({
          where: { id: input.target_id },
          data: { bookmarkCount: { increment: 1 } },
        });
      }
    });
    return { saved: true };
  }

  async listForUser(
    viewer: Viewer & { id: string },
    type?: string,
  ): Promise<SavedItemListDTO> {
    const allowed = this.access.accessPoliciesAllowedFor(viewer);
    const typeFilter = type && VALID_TYPES.includes(type as SaveTargetType)
      ? (type as SaveTargetType)
      : undefined;

    const rows = await this.prisma.savedItem.findMany({
      where: {
        userId: viewer.id,
        ...(typeFilter ? { targetType: typeFilter } : {}),
      },
      orderBy: { createdAt: 'desc' },
    });

    const items: SavedItemDTO[] = [];
    for (const row of rows) {
      const target = await this.resolveTarget(
        row.targetType as SaveTargetType,
        row.targetId,
        allowed,
      );
      if (!target) continue; // access-filtered or deleted
      items.push({
        id: row.id,
        target_type: row.targetType as SaveTargetType,
        target_id: row.targetId,
        saved_at: row.createdAt.toISOString(),
        target,
      });
    }

    return { items };
  }

  async isSaved(
    targetType: string,
    targetId: string,
    userId: string,
  ): Promise<{ saved: boolean }> {
    const row = await this.prisma.savedItem.findUnique({
      where: {
        userId_targetType_targetId: { userId, targetType, targetId },
      },
    });
    return { saved: !!row };
  }

  private async assertTargetExists(type: SaveTargetType, id: string): Promise<void> {
    let found = false;
    if (type === 'POST') {
      found = !!(await this.prisma.post.findUnique({ where: { id }, select: { id: true } }));
    } else if (type === 'REFERENCE') {
      found = !!(await this.prisma.reference.findUnique({ where: { id }, select: { id: true } }));
    } else if (type === 'EVENT_CARD') {
      found = !!(await this.prisma.eventCard.findUnique({ where: { id }, select: { id: true } }));
    }
    if (!found) throw new NotFoundException(`${type} not found: ${id}`);
  }

  private async resolveTarget(
    type: SaveTargetType,
    id: string,
    allowed: string[],
  ): Promise<Record<string, unknown> | null> {
    if (type === 'POST') {
      const post = await this.prisma.post.findFirst({
        where: {
          id,
          status: { notIn: ['DELETED', 'HIDDEN'] },
          room: { category: { space: { accessPolicy: { in: allowed } } } },
        },
        include: {
          room: true,
          author: { include: { profile: true } },
        },
      });
      if (!post) return null;
      return {
        id: post.id,
        body_preview: post.body.slice(0, 80),
        room_name: post.room.name,
        room_slug: post.room.slug,
        author_nickname: (post.author as any).profile?.nickname ?? '',
        created_at: post.createdAt.toISOString(),
      };
    }

    if (type === 'REFERENCE') {
      const ref = await this.prisma.reference.findFirst({
        where: { id, status: 'VISIBLE' },
      });
      if (!ref) return null;
      return {
        id: ref.id,
        type: ref.type,
        url: ref.url,
        title: ref.title,
        source_name: ref.sourceName,
        thumbnail_url: ref.thumbnailUrl,
        summary: ref.summary,
      };
    }

    if (type === 'EVENT_CARD') {
      const card = await this.prisma.eventCard.findUnique({ where: { id } });
      if (!card) return null;
      return {
        id: card.id,
        title: card.title,
        venue_name: card.venueName,
        region: card.region,
        starts_at: card.startsAt.toISOString(),
        event_status: card.eventStatus,
        thumbnail_url: card.thumbnailUrl,
      };
    }

    return null;
  }
}
