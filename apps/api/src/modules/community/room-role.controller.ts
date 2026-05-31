import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
} from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { RoomRoleService } from './room-role.service';

interface GrantBody {
  user_id?: string;
  role?: string;
}

@Controller('rooms/:slug/roles')
export class RoomRoleController {
  constructor(private readonly svc: RoomRoleService) {}

  /** Active room-role roster (owner-managed moderators). */
  @Get()
  list(@Param('slug') slug: string) {
    return this.svc.listForRoom(slug);
  }

  /**
   * P6.12 — grant a room role. Owner-only (enforced in the service);
   * `role` defaults to MODERATOR. Idempotent — re-granting un-revokes.
   */
  @Post()
  @HttpCode(200)
  grant(
    @Param('slug') slug: string,
    @Body() body: GrantBody,
    @CurrentUser() actor: RequestUser,
  ) {
    return this.svc.grant(
      slug,
      actor,
      body?.user_id ?? '',
      body?.role ?? 'MODERATOR',
    );
  }

  /** Soft-revoke a member's room role. Owner-only. */
  @Delete(':userId')
  @HttpCode(200)
  revoke(
    @Param('slug') slug: string,
    @Param('userId') userId: string,
    @CurrentUser() actor: RequestUser,
  ) {
    return this.svc.revoke(slug, actor, userId);
  }
}
