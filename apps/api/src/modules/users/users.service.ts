import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true, roles: true },
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return {
      id: user.id,
      status: user.status,
      nickname: user.profile?.nickname ?? null,
      avatar_url: user.profile?.avatarUrl ?? null,
      bio: user.profile?.bio ?? null,
      region: user.profile?.region ?? null,
      interests: user.profile?.interests ?? [],
      roles: user.roles.map((r) => r.role),
    };
  }

  async listDevUsers() {
    const users = await this.prisma.user.findMany({
      where: { status: 'ACTIVE' },
      include: { profile: true },
      orderBy: { createdAt: 'asc' },
    });
    return users.map((u) => ({
      id: u.id,
      nickname: u.profile?.nickname ?? '(no profile)',
    }));
  }

  /**
   * P6.1 mention autocomplete. Lookup by nickname prefix (case
   * insensitive via the lowercased nickname index). Hard cap at 8 hits
   * so the composer dropdown stays bounded. Status=ACTIVE only — we
   * never surface a deleted account as a mention candidate.
   */
  async searchByNickname(
    prefix: string,
    limit = 8,
  ): Promise<{ id: string; nickname: string; avatar_url: string | null }[]> {
    const q = prefix.trim();
    if (q.length === 0) return [];
    const cap = Math.max(1, Math.min(limit, 20));
    const rows = await this.prisma.profile.findMany({
      where: {
        nickname: { startsWith: q, mode: 'insensitive' },
        user: { status: 'ACTIVE' },
      },
      include: { user: { select: { id: true, status: true } } },
      take: cap,
      orderBy: { nickname: 'asc' },
    });
    return rows.map((r) => ({
      id: r.userId,
      nickname: r.nickname,
      avatar_url: r.avatarUrl,
    }));
  }
}
