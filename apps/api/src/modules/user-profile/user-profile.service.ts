import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService, Viewer } from '../../shared/access-control.service';
import { PostService } from '../posts/post.service';
import {
  ApprovedContributionDTO,
  ProfileSubDTO,
  UpdateProfileInput,
  UserProfileBundleDTO,
} from './dto/user-profile.dto';

const BIO_MAX = 500;
const REGION_MAX = 50;
const INTEREST_MAX = 30;
const INTERESTS_MAX_COUNT = 10;

const POST_INCLUDE = {
  room: true,
  author: { include: { profile: true } },
  attachments: true,
} as const;

@Injectable()
export class UserProfileService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
    private readonly postService: PostService,
  ) {}

  async getProfileBundle(
    userId: string,
    viewer: Viewer & { id: string },
  ): Promise<UserProfileBundleDTO> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true, roles: true },
    });
    if (!user) throw new NotFoundException(`User not found: ${userId}`);

    const allowed = this.access.accessPoliciesAllowedFor(viewer);
    const isVerifiedPlanner = this.access.isVerifiedPlanner(viewer);

    // Build the post WHERE filter:
    //  - Always exclude DELETED.
    //  - Restrict by space access policy.
    //  - Exclude RECRUITMENT posts when viewer is not a planner (consistent
    //    with how M4 PostService gates recruitment visibility).
    const postWhere = {
      authorId: userId,
      status: { not: 'DELETED' },
      room: { category: { space: { accessPolicy: { in: allowed } } } },
      ...(isVerifiedPlanner ? {} : { postType: { not: 'RECRUITMENT' } }),
    };

    const [
      recentPostRows,
      postCount,
      userRoomRows,
      roomCount,
      approvedContribRows,
      followerCount,
      followingCount,
      followRow,
    ] = await Promise.all([
      this.prisma.post.findMany({
        where: postWhere,
        orderBy: { createdAt: 'desc' },
        take: 5,
        include: POST_INCLUDE,
      }),
      this.prisma.post.count({ where: postWhere }),
      this.prisma.room.findMany({
        where: {
          ownerId: userId,
          origin: 'USER',
          category: { space: { accessPolicy: { in: allowed } } },
        },
        include: { owner: { include: { profile: true } } },
        orderBy: { createdAt: 'desc' },
        take: 5,
      }),
      this.prisma.room.count({
        where: {
          ownerId: userId,
          origin: 'USER',
          category: { space: { accessPolicy: { in: allowed } } },
        },
      }),
      this.prisma.knowledgeContribution.findMany({
        where: {
          contributorId: userId,
          status: 'APPROVED',
          hub: { category: { space: { accessPolicy: { in: allowed } } } },
        },
        include: { hub: { include: { category: true } } },
        orderBy: { resolvedAt: 'desc' },
        take: 5,
      }),
      this.prisma.userFollow.count({ where: { followedId: userId } }),
      this.prisma.userFollow.count({ where: { followerId: userId } }),
      viewer.id === userId
        ? Promise.resolve(null)
        : this.prisma.userFollow.findUnique({
            where: {
              followerId_followedId: {
                followerId: viewer.id,
                followedId: userId,
              },
            },
          }),
    ]);

    const recentPosts = await this.postService.postsToDTOs(
      recentPostRows,
      viewer.id,
    );

    const userRooms = userRoomRows.map((r) => ({
      id: r.id,
      slug: r.slug,
      name: r.name,
      description: r.description,
      origin: r.origin as 'OFFICIAL' | 'USER',
      room_type: r.roomType,
      owner_nickname: (r.owner as any)?.profile?.nickname ?? null,
    }));

    const approvedContributions: ApprovedContributionDTO[] = approvedContribRows.map(
      (c) => ({
        id: c.id,
        topic_hub_title: c.hub.title,
        category_slug: c.hub.category.slug,
        decision: 'APPROVED',
        resolved_at: (c.resolvedAt ?? c.updatedAt).toISOString(),
      }),
    );

    const interests = Array.isArray(user.profile?.interests)
      ? (user.profile!.interests as string[])
      : [];

    return {
      user: {
        id: user.id,
        nickname: user.profile?.nickname ?? null,
        avatar_url: user.profile?.avatarUrl ?? null,
        status: user.status,
        created_at: user.createdAt.toISOString(),
      },
      profile: {
        bio: user.profile?.bio ?? null,
        region: user.profile?.region ?? null,
        interests,
      },
      roles: user.roles.map((r) => r.role),
      counts: {
        post_count: postCount,
        room_count: roomCount,
        follower_count: followerCount,
        following_count: followingCount,
      },
      recent_posts: recentPosts,
      user_rooms: userRooms,
      approved_contributions: approvedContributions,
      is_self: viewer.id === userId,
      is_following: !!followRow,
    };
  }

  async updateMyProfile(
    viewerId: string,
    input: UpdateProfileInput,
  ): Promise<ProfileSubDTO> {
    this.assertAllowedKeys(input);

    const updateData: {
      bio?: string | null;
      region?: string | null;
      interests?: string[];
    } = {};

    if (input.bio !== undefined) {
      if (input.bio === null) {
        updateData.bio = null;
      } else {
        if (typeof input.bio !== 'string') {
          throw new BadRequestException('bio must be a string');
        }
        const trimmed = input.bio.trim();
        if (trimmed.length > BIO_MAX) {
          throw new BadRequestException(`bio must be at most ${BIO_MAX} characters`);
        }
        updateData.bio = trimmed.length === 0 ? null : trimmed;
      }
    }

    if (input.region !== undefined) {
      if (input.region === null) {
        updateData.region = null;
      } else {
        if (typeof input.region !== 'string') {
          throw new BadRequestException('region must be a string');
        }
        const trimmed = input.region.trim();
        if (trimmed.length > REGION_MAX) {
          throw new BadRequestException(
            `region must be at most ${REGION_MAX} characters`,
          );
        }
        updateData.region = trimmed.length === 0 ? null : trimmed;
      }
    }

    if (input.interests !== undefined) {
      if (!Array.isArray(input.interests)) {
        throw new BadRequestException('interests must be an array');
      }
      const normalized: string[] = [];
      const seen = new Set<string>();
      for (const raw of input.interests) {
        if (typeof raw !== 'string') {
          throw new BadRequestException('each interest must be a string');
        }
        const t = raw.trim().toLowerCase();
        if (t.length === 0) continue;
        if (t.length > INTEREST_MAX) {
          throw new BadRequestException(
            `each interest must be at most ${INTEREST_MAX} characters`,
          );
        }
        if (!seen.has(t)) {
          seen.add(t);
          normalized.push(t);
        }
      }
      if (normalized.length > INTERESTS_MAX_COUNT) {
        throw new BadRequestException(
          `interests must have at most ${INTERESTS_MAX_COUNT} items`,
        );
      }
      updateData.interests = normalized;
    }

    const profile = await this.prisma.profile.update({
      where: { userId: viewerId },
      data: updateData,
    });

    return {
      bio: profile.bio,
      region: profile.region,
      interests: Array.isArray(profile.interests)
        ? (profile.interests as string[])
        : [],
    };
  }

  private assertAllowedKeys(input: UpdateProfileInput): void {
    const allowed = new Set(['bio', 'region', 'interests']);
    const extra = Object.keys(input).filter((k) => !allowed.has(k));
    if (extra.length > 0) {
      throw new BadRequestException(`Unsupported fields: ${extra.join(', ')}`);
    }
  }
}
