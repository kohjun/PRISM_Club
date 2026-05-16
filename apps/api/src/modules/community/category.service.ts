import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService, Viewer } from '../../shared/access-control.service';

@Injectable()
export class CategoryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
  ) {}

  async listBySpaceSlug(spaceSlug: string, viewer: Viewer) {
    await this.access.assertCanReadSpaceBySlug(spaceSlug, viewer);

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

  /**
   * Access-naive lookup used by other services after they've already gated
   * the request via AccessControlService. Throws NotFound if absent.
   */
  async findBySlug(slug: string) {
    const cat = await this.prisma.category.findUnique({ where: { slug } });
    if (!cat) {
      throw new NotFoundException(`Category not found: ${slug}`);
    }
    return cat;
  }
}
