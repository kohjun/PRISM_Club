import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';

@Injectable()
export class SpaceService {
  constructor(private readonly prisma: PrismaService) {}

  async listSpaces() {
    const spaces = await this.prisma.space.findMany({
      where: { status: 'ACTIVE' },
      orderBy: { audience: 'asc' },
    });
    return spaces.map((s) => ({
      id: s.id,
      slug: s.slug,
      name: s.name,
      audience: s.audience,
      access_policy: s.accessPolicy,
    }));
  }
}
