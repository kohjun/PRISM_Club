import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from './prisma.service';

export interface Viewer {
  roles: string[];
}

/**
 * Milestone 4: data-driven access gate that consults `Space.accessPolicy`.
 *
 * `Space.accessPolicy` is `'PUBLIC'` for the participant space and
 * `'PLANNER_ONLY'` for the planner space. A viewer is allowed to read a space
 * if its policy appears in `accessPoliciesAllowedFor(viewer)`.
 *
 * Verified Planners and Admins see both PUBLIC and PLANNER_ONLY content.
 * Plain members see only PUBLIC.
 */
@Injectable()
export class AccessControlService {
  constructor(private readonly prisma: PrismaService) {}

  accessPoliciesAllowedFor(user: Viewer): string[] {
    const allowed = ['PUBLIC'];
    if (
      user.roles.includes('VERIFIED_PLANNER') ||
      user.roles.includes('ADMIN')
    ) {
      allowed.push('PLANNER_ONLY');
    }
    return allowed;
  }

  isVerifiedPlanner(user: Viewer): boolean {
    return (
      user.roles.includes('VERIFIED_PLANNER') || user.roles.includes('ADMIN')
    );
  }

  async assertCanReadSpaceBySlug(slug: string, user: Viewer): Promise<void> {
    const space = await this.prisma.space.findUnique({ where: { slug } });
    if (!space) {
      throw new NotFoundException(`Space not found: ${slug}`);
    }
    this.assertPolicy(space.accessPolicy, user);
  }

  async assertCanReadCategoryBySlug(slug: string, user: Viewer): Promise<void> {
    const cat = await this.prisma.category.findUnique({
      where: { slug },
      include: { space: true },
    });
    if (!cat) {
      throw new NotFoundException(`Category not found: ${slug}`);
    }
    this.assertPolicy(cat.space.accessPolicy, user);
  }

  async assertCanReadRoomBySlug(slug: string, user: Viewer): Promise<void> {
    const room = await this.prisma.room.findUnique({
      where: { slug },
      include: { category: { include: { space: true } } },
    });
    if (!room) {
      throw new NotFoundException(`Room not found: ${slug}`);
    }
    this.assertPolicy(room.category.space.accessPolicy, user);
  }

  private assertPolicy(policy: string, user: Viewer): void {
    if (!this.accessPoliciesAllowedFor(user).includes(policy)) {
      throw new ForbiddenException(
        'This community requires Verified Planner access.',
      );
    }
  }
}
