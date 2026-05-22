import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma.service';

const MAX_COLLECTIONS_PER_USER = 20;
const NAME_MIN = 1;
const NAME_MAX = 50;

export interface SavedCollectionDTO {
  id: string;
  name: string;
  sort_order: number;
  item_count: number;
  created_at: string;
}

/**
 * P4.4 saved-items folder service. Each user can have up to 20
 * collections (`MAX_COLLECTIONS_PER_USER`); within a user, names are
 * unique. Deleting a collection nulls the `collection_id` on its
 * saved_items (FK = SET NULL) so the saves themselves survive.
 */
@Injectable()
export class SaveCollectionService {
  constructor(private readonly prisma: PrismaService) {}

  async listForUser(userId: string): Promise<SavedCollectionDTO[]> {
    const rows = await this.prisma.savedCollection.findMany({
      where: { userId },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
      include: { _count: { select: { savedItems: true } } },
    });
    return rows.map((r) => ({
      id: r.id,
      name: r.name,
      sort_order: r.sortOrder,
      item_count: r._count.savedItems,
      created_at: r.createdAt.toISOString(),
    }));
  }

  async create(
    userId: string,
    name: string,
  ): Promise<SavedCollectionDTO> {
    const trimmed = (name ?? '').trim();
    if (trimmed.length < NAME_MIN || trimmed.length > NAME_MAX) {
      throw new BadRequestException(
        `name length must be ${NAME_MIN}..${NAME_MAX}`,
      );
    }
    const count = await this.prisma.savedCollection.count({ where: { userId } });
    if (count >= MAX_COLLECTIONS_PER_USER) {
      throw new ConflictException(
        `Maximum ${MAX_COLLECTIONS_PER_USER} collections per user`,
      );
    }
    try {
      const row = await this.prisma.savedCollection.create({
        data: { userId, name: trimmed, sortOrder: count },
        include: { _count: { select: { savedItems: true } } },
      });
      return {
        id: row.id,
        name: row.name,
        sort_order: row.sortOrder,
        item_count: row._count.savedItems,
        created_at: row.createdAt.toISOString(),
      };
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        throw new ConflictException('A collection with that name already exists');
      }
      throw e;
    }
  }

  async patch(
    userId: string,
    id: string,
    input: { name?: string; sort_order?: number },
  ): Promise<SavedCollectionDTO> {
    const data: { name?: string; sortOrder?: number } = {};
    if (input.name !== undefined) {
      const trimmed = input.name.trim();
      if (trimmed.length < NAME_MIN || trimmed.length > NAME_MAX) {
        throw new BadRequestException(
          `name length must be ${NAME_MIN}..${NAME_MAX}`,
        );
      }
      data.name = trimmed;
    }
    if (input.sort_order !== undefined) {
      data.sortOrder = input.sort_order;
    }
    const existing = await this.prisma.savedCollection.findUnique({
      where: { id },
    });
    if (!existing || existing.userId !== userId) {
      throw new NotFoundException(`Collection not found: ${id}`);
    }
    try {
      const row = await this.prisma.savedCollection.update({
        where: { id },
        data,
        include: { _count: { select: { savedItems: true } } },
      });
      return {
        id: row.id,
        name: row.name,
        sort_order: row.sortOrder,
        item_count: row._count.savedItems,
        created_at: row.createdAt.toISOString(),
      };
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        throw new ConflictException('A collection with that name already exists');
      }
      throw e;
    }
  }

  async delete(userId: string, id: string): Promise<{ ok: boolean }> {
    const existing = await this.prisma.savedCollection.findUnique({
      where: { id },
    });
    if (!existing || existing.userId !== userId) {
      throw new NotFoundException(`Collection not found: ${id}`);
    }
    await this.prisma.savedCollection.delete({ where: { id } });
    return { ok: true };
  }

  /**
   * Move a save into (or out of) a collection. `collectionId === null`
   * pulls the save back to the uncategorised bucket.
   */
  async moveSave(
    userId: string,
    saveId: string,
    collectionId: string | null,
  ): Promise<{ ok: boolean }> {
    const save = await this.prisma.savedItem.findUnique({
      where: { id: saveId },
    });
    if (!save || save.userId !== userId) {
      throw new NotFoundException(`Saved item not found: ${saveId}`);
    }
    if (collectionId !== null) {
      const target = await this.prisma.savedCollection.findUnique({
        where: { id: collectionId },
      });
      if (!target || target.userId !== userId) {
        throw new NotFoundException(`Collection not found: ${collectionId}`);
      }
    }
    await this.prisma.savedItem.update({
      where: { id: saveId },
      data: { collectionId },
    });
    return { ok: true };
  }
}
