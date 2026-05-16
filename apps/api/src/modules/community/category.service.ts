import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';

@Injectable()
export class CategoryService {
  constructor(private readonly prisma: PrismaService) {}

  async listBySpaceSlug(spaceSlug: string) {
    const space = await this.prisma.space.findUnique({ where: { slug: spaceSlug } });
    if (!space) {
      throw new NotFoundException(`Space not found: ${spaceSlug}`);
    }

    const cats = await this.prisma.category.findMany({
      where: { spaceId: space.id, status: 'ACTIVE' },
      orderBy: { sortOrder: 'asc' },
    });
    return cats.map((c) => ({
      id: c.id,
      slug: c.slug,
      name: c.name,
      description: c.description,
      space: { slug: space.slug, name: space.name },
    }));
  }

  async findBySlug(slug: string) {
    const cat = await this.prisma.category.findUnique({ where: { slug } });
    if (!cat) {
      throw new NotFoundException(`Category not found: ${slug}`);
    }
    return cat;
  }
}
