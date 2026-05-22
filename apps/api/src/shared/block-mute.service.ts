import {
  BadRequestException,
  ConflictException,
  Global,
  Injectable,
  Module,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from './prisma.service';
import { PrismaModule } from './prisma.module';

/**
 * P6.2 block + mute primitives.
 *
 * Block (bidirectional effect):
 *   - blocker no longer sees content from blocked (timeline, replies,
 *     search, notifications)
 *   - blocked cannot reply / quote / mention / follow the blocker
 *
 * Mute (unidirectional, soft):
 *   - muter hides muted's content from their feed + inbox
 *   - muted is unaware
 *
 * The service is exported globally so any feature module
 * (posts / replies / mentions / follows / notifications) can ask
 * "is this pair blocked?" without a fresh module wiring per consumer.
 */
@Injectable()
export class BlockMuteService {
  constructor(private readonly prisma: PrismaService) {}

  // ---- WRITE ----------------------------------------------------------

  async block(blockerId: string, blockedId: string): Promise<void> {
    if (blockerId === blockedId) {
      throw new BadRequestException('Cannot block yourself');
    }
    const target = await this.prisma.user.findUnique({
      where: { id: blockedId },
      select: { id: true, status: true },
    });
    if (!target || target.status !== 'ACTIVE') {
      throw new NotFoundException('Target user not found');
    }
    try {
      await this.prisma.userBlock.create({
        data: { blockerId, blockedId },
      });
    } catch (e) {
      // P2002 = unique violation. Idempotent: already blocked → no-op.
      if ((e as { code?: string }).code === 'P2002') return;
      throw e;
    }
    // Block implies unfollow on both sides — block is louder than follow.
    await this.prisma.userFollow.deleteMany({
      where: {
        OR: [
          { followerId: blockerId, followedId: blockedId },
          { followerId: blockedId, followedId: blockerId },
        ],
      },
    });
  }

  async unblock(blockerId: string, blockedId: string): Promise<void> {
    await this.prisma.userBlock.deleteMany({
      where: { blockerId, blockedId },
    });
  }

  async mute(muterId: string, mutedId: string): Promise<void> {
    if (muterId === mutedId) {
      throw new BadRequestException('Cannot mute yourself');
    }
    try {
      await this.prisma.userMute.create({
        data: { muterId, mutedId },
      });
    } catch (e) {
      if ((e as { code?: string }).code === 'P2002') return;
      throw e;
    }
  }

  async unmute(muterId: string, mutedId: string): Promise<void> {
    await this.prisma.userMute.deleteMany({
      where: { muterId, mutedId },
    });
  }

  // ---- READ -----------------------------------------------------------

  /**
   * `targetId` is hidden FROM `viewerId`'s view when:
   *   - viewer blocks target, OR
   *   - target blocks viewer (defense — blocked party shouldn't see the
   *     blocker either, to prevent context-collapse)
   *
   * Use in read paths (timeline, replies, search) AND write-side guards
   * (reply/quote/mention/follow rejection).
   */
  async isBlockedEitherWay(
    viewerId: string,
    targetId: string,
  ): Promise<boolean> {
    if (viewerId === targetId) return false;
    const row = await this.prisma.userBlock.findFirst({
      where: {
        OR: [
          { blockerId: viewerId, blockedId: targetId },
          { blockerId: targetId, blockedId: viewerId },
        ],
      },
      select: { blockerId: true },
    });
    return !!row;
  }

  /**
   * Whether `viewerId` has explicitly muted `targetId`. Used for
   * notification filtering only — write-side never consults mute.
   */
  async isMuted(viewerId: string, targetId: string): Promise<boolean> {
    if (viewerId === targetId) return false;
    const row = await this.prisma.userMute.findUnique({
      where: { muterId_mutedId: { muterId: viewerId, mutedId: targetId } },
      select: { muterId: true },
    });
    return !!row;
  }

  /**
   * Bulk version. Pass a list of candidate user ids and get back a set
   * of those who are blocked-either-way against viewer. Used in
   * timeline / search filters where the candidate set is known.
   */
  async blockedSetFor(
    viewerId: string,
    candidateIds: string[],
  ): Promise<Set<string>> {
    if (candidateIds.length === 0) return new Set();
    const rows = await this.prisma.userBlock.findMany({
      where: {
        OR: [
          { blockerId: viewerId, blockedId: { in: candidateIds } },
          { blockerId: { in: candidateIds }, blockedId: viewerId },
        ],
      },
      select: { blockerId: true, blockedId: true },
    });
    const out = new Set<string>();
    for (const r of rows) {
      out.add(r.blockerId === viewerId ? r.blockedId : r.blockerId);
    }
    return out;
  }

  /**
   * Bulk mute set — exact mirror of `blockedSetFor` but for mutes.
   */
  async mutedSetFor(
    viewerId: string,
    candidateIds: string[],
  ): Promise<Set<string>> {
    if (candidateIds.length === 0) return new Set();
    const rows = await this.prisma.userMute.findMany({
      where: { muterId: viewerId, mutedId: { in: candidateIds } },
      select: { mutedId: true },
    });
    return new Set(rows.map((r) => r.mutedId));
  }

  // ---- LIST -----------------------------------------------------------

  async listBlocks(viewerId: string): Promise<BlockMuteEntryDTO[]> {
    const rows = await this.prisma.userBlock.findMany({
      where: { blockerId: viewerId },
      include: { blocked: { include: { profile: true } } },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((r) => ({
      user_id: r.blockedId,
      nickname: r.blocked.profile?.nickname ?? null,
      avatar_url: r.blocked.profile?.avatarUrl ?? null,
      created_at: r.createdAt.toISOString(),
    }));
  }

  async listMutes(viewerId: string): Promise<BlockMuteEntryDTO[]> {
    const rows = await this.prisma.userMute.findMany({
      where: { muterId: viewerId },
      include: { muted: { include: { profile: true } } },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((r) => ({
      user_id: r.mutedId,
      nickname: r.muted.profile?.nickname ?? null,
      avatar_url: r.muted.profile?.avatarUrl ?? null,
      created_at: r.createdAt.toISOString(),
    }));
  }
}

export interface BlockMuteEntryDTO {
  user_id: string;
  nickname: string | null;
  avatar_url: string | null;
  created_at: string;
}

/**
 * Throw if `viewerId` and `targetId` are blocked either way. Common
 * write-side guard wrapper so PostService.create() / ReplyService.create()
 * /UserFollowService.toggle() can `await assertNotBlocked()` in one
 * line.
 */
export async function assertNotBlocked(
  svc: BlockMuteService,
  viewerId: string,
  targetId: string,
): Promise<void> {
  if (await svc.isBlockedEitherWay(viewerId, targetId)) {
    throw new ConflictException('이 사용자와 차단 관계라 진행할 수 없어요.');
  }
}

@Global()
@Module({
  imports: [PrismaModule],
  providers: [BlockMuteService],
  exports: [BlockMuteService],
})
export class BlockMuteModule {}
