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
}
