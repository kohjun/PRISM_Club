import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';

const VALID_ROLES = new Set(['MODERATOR', 'MEMBER']);
const GLOBAL_MOD_ROLES = ['MODERATOR', 'ADMIN'];

export interface RoomRoleDTO {
  user_id: string;
  nickname: string | null;
  role: string;
  granted_at: string;
}

interface Actor {
  id: string;
  roles: string[];
}

/**
 * P6.12 — delegated per-room moderation.
 *
 * A room owner promotes trusted members to a room-scoped MODERATOR
 * role so they don't have to grant the heavyweight *global* MODERATOR.
 * Escalation is guarded by construction + explicit checks:
 *   - Only the room OWNER can grant/revoke (a room moderator cannot
 *     mint more moderators — no privilege self-propagation).
 *   - This service only ever writes `room_roles`, never `user_roles`,
 *     so a room grant can never become a global role.
 *   - Owners can't grant to themselves (they already moderate) and
 *     can't grant to an inactive/unknown user.
 *
 * `canModerateRoom` is the single read used by moderation actions:
 * owner OR an active room MODERATOR OR a global MODERATOR/ADMIN.
 */
@Injectable()
export class RoomRoleService {
  constructor(private readonly prisma: PrismaService) {}

  async listForRoom(slug: string): Promise<RoomRoleDTO[]> {
    const room = await this._roomBySlug(slug);
    const rows = await this.prisma.roomRole.findMany({
      where: { roomId: room.id, revokedAt: null },
      include: { user: { include: { profile: true } } },
      orderBy: { grantedAt: 'desc' },
    });
    return rows.map((r) => ({
      user_id: r.userId,
      nickname: r.user.profile?.nickname ?? null,
      role: r.role,
      granted_at: r.grantedAt.toISOString(),
    }));
  }

  async grant(
    slug: string,
    actor: Actor,
    targetUserId: string,
    role: string,
  ): Promise<RoomRoleDTO> {
    if (!VALID_ROLES.has(role)) {
      throw new BadRequestException(
        `role must be one of ${[...VALID_ROLES].join(', ')}`,
      );
    }
    const room = await this._roomBySlug(slug);
    this._assertOwner(room.ownerId, actor);

    if (targetUserId === actor.id) {
      throw new BadRequestException(
        '방장은 이미 모더 권한이 있어 자기 자신에게 부여할 수 없어요.',
      );
    }
    const target = await this.prisma.user.findUnique({
      where: { id: targetUserId },
      include: { profile: true },
    });
    if (!target || target.status !== 'ACTIVE') {
      throw new NotFoundException('대상 사용자를 찾을 수 없어요.');
    }

    const row = await this.prisma.roomRole.upsert({
      where: { roomId_userId: { roomId: room.id, userId: targetUserId } },
      create: {
        roomId: room.id,
        userId: targetUserId,
        role,
        grantedBy: actor.id,
      },
      update: { role, grantedBy: actor.id, revokedAt: null },
    });
    return {
      user_id: row.userId,
      nickname: target.profile?.nickname ?? null,
      role: row.role,
      granted_at: row.grantedAt.toISOString(),
    };
  }

  async revoke(
    slug: string,
    actor: Actor,
    targetUserId: string,
  ): Promise<{ ok: boolean }> {
    const room = await this._roomBySlug(slug);
    this._assertOwner(room.ownerId, actor);
    await this.prisma.roomRole.updateMany({
      where: { roomId: room.id, userId: targetUserId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { ok: true };
  }

  /**
   * Single source of truth for "may this viewer moderate this room".
   * Consumed by post/reply hide actions (room owner + delegated room
   * moderators + global staff).
   */
  async canModerateRoom(actor: Actor, roomId: string): Promise<boolean> {
    if (actor.roles.some((r) => GLOBAL_MOD_ROLES.includes(r))) return true;
    const room = await this.prisma.room.findUnique({
      where: { id: roomId },
      select: { ownerId: true },
    });
    if (!room) return false;
    if (room.ownerId === actor.id) return true;
    const mod = await this.prisma.roomRole.findFirst({
      where: {
        roomId,
        userId: actor.id,
        role: 'MODERATOR',
        revokedAt: null,
      },
      select: { id: true },
    });
    return mod != null;
  }

  // ---- internals ---------------------------------------------------

  private async _roomBySlug(
    slug: string,
  ): Promise<{ id: string; ownerId: string | null }> {
    const room = await this.prisma.room.findUnique({
      where: { slug },
      select: { id: true, ownerId: true },
    });
    if (!room) throw new NotFoundException(`Room not found: ${slug}`);
    return room;
  }

  private _assertOwner(ownerId: string | null, actor: Actor): void {
    // Deliberately owner-ONLY — global admins can moderate content but
    // do not manage a room's delegated roster, and room moderators
    // can't mint peers. This is the core anti-escalation guard.
    if (!ownerId || ownerId !== actor.id) {
      throw new ForbiddenException('방장만 모더 권한을 관리할 수 있어요.');
    }
  }
}
