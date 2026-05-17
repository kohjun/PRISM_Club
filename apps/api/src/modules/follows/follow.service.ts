import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService, Viewer } from '../../shared/access-control.service';

export interface FollowStateDTO {
  followed: boolean;
  follower_count: number;
}

@Injectable()
export class FollowService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
  ) {}

  async toggle(roomSlug: string, viewer: Viewer & { id: string }): Promise<FollowStateDTO> {
    await this.access.assertCanReadRoomBySlug(roomSlug, viewer);
    const room = await this.prisma.room.findUnique({ where: { slug: roomSlug } });
    // assertCanReadRoomBySlug throws NotFoundException if not found
    const existing = await this.prisma.roomFollow.findUnique({
      where: { userId_roomId: { userId: viewer.id, roomId: room!.id } },
    });
    if (existing) {
      await this.prisma.roomFollow.delete({ where: { id: existing.id } });
    } else {
      await this.prisma.roomFollow.create({
        data: { userId: viewer.id, roomId: room!.id },
      });
    }
    return this.getState(roomSlug, viewer.id);
  }

  async getState(roomSlug: string, userId: string): Promise<FollowStateDTO> {
    const room = await this.prisma.room.findUnique({ where: { slug: roomSlug } });
    if (!room) return { followed: false, follower_count: 0 };
    const [followed, follower_count] = await Promise.all([
      this.prisma.roomFollow.findUnique({
        where: { userId_roomId: { userId, roomId: room.id } },
      }),
      this.prisma.roomFollow.count({ where: { roomId: room.id } }),
    ]);
    return { followed: !!followed, follower_count };
  }
}
