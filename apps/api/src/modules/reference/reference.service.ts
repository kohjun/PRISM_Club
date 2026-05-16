import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { RoomService } from '../community/room.service';

export interface CreateReferenceInput {
  url: string;
  title: string;
  type: string;
  source_name?: string;
  thumbnail_url?: string;
  summary?: string;
}

const ALLOWED_TYPES = new Set([
  'TV_SHOW',
  'YOUTUBE',
  'GAME_RULE',
  'ARTICLE',
  'IDEA',
  'OTHER',
]);

@Injectable()
export class ReferenceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: RoomService,
  ) {}

  async create(input: CreateReferenceInput, userId: string) {
    const type = ALLOWED_TYPES.has(input.type) ? input.type : 'OTHER';
    const created = await this.prisma.reference.create({
      data: {
        createdBy: userId,
        url: input.url,
        title: input.title,
        type,
        sourceName: input.source_name ?? null,
        thumbnailUrl: input.thumbnail_url ?? null,
        summary: input.summary ?? null,
      },
    });
    return this.rooms.toReferenceDTO(created);
  }

  async findByIds(ids: string[]) {
    if (ids.length === 0) return [];
    const rows = await this.prisma.reference.findMany({
      where: { id: { in: ids } },
    });
    return rows.map((r) => this.rooms.toReferenceDTO(r));
  }
}
