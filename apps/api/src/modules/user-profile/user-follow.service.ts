import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import {
  BlockMuteService,
  assertNotBlocked,
} from '../../shared/block-mute.service';
import { FollowStateDTO } from './dto/user-profile.dto';

@Injectable()
export class UserFollowService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly blockMute: BlockMuteService,
  ) {}

  async toggle(targetUserId: string, viewerId: string): Promise<FollowStateDTO> {
    if (targetUserId === viewerId) {
      throw new BadRequestException('Cannot follow yourself');
    }
    const target = await this.prisma.user.findUnique({
      where: { id: targetUserId },
      select: { id: true },
    });
    if (!target) {
      throw new NotFoundException(`User not found: ${targetUserId}`);
    }
    // P6.2: a follow can't form across a block in either direction.
    // Unblock first; UserFollow rows linked to a previous follow are
    // already cleared inside BlockMuteService.block().
    await assertNotBlocked(this.blockMute, viewerId, targetUserId);
    const existing = await this.prisma.userFollow.findUnique({
      where: {
        followerId_followedId: {
          followerId: viewerId,
          followedId: targetUserId,
        },
      },
    });
    if (existing) {
      await this.prisma.userFollow.delete({ where: { id: existing.id } });
    } else {
      await this.prisma.userFollow.create({
        data: { followerId: viewerId, followedId: targetUserId },
      });
    }
    return this.getState(targetUserId, viewerId);
  }

  async getState(targetUserId: string, viewerId: string): Promise<FollowStateDTO> {
    const target = await this.prisma.user.findUnique({
      where: { id: targetUserId },
      select: { id: true },
    });
    if (!target) {
      return { followed: false, follower_count: 0 };
    }
    const [followRow, follower_count] = await Promise.all([
      viewerId === targetUserId
        ? Promise.resolve(null)
        : this.prisma.userFollow.findUnique({
            where: {
              followerId_followedId: {
                followerId: viewerId,
                followedId: targetUserId,
              },
            },
          }),
      this.prisma.userFollow.count({ where: { followedId: targetUserId } }),
    ]);
    return { followed: !!followRow, follower_count };
  }
}
