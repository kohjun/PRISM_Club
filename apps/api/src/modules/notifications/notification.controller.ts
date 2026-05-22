import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { CurrentUser } from '../../shared/decorators/current-user.decorator';
import { RequestUser } from '../../shared/decorators/current-user.decorator';
import { NotificationService } from './notification.service';
import { NotificationPreferencesService } from './notification-preferences.service';
import { DeviceTokenService } from './device-token.service';

interface RegisterDeviceTokenBody {
  token?: string;
  platform?: string;
  provider?: string;
  app_version?: string;
  device_model?: string;
  locale?: string;
}

interface UpdatePrefsBody {
  pref_reply_on_post?: boolean;
  pref_nested_reply?: boolean;
  pref_new_post_in_followed_room?: boolean;
  pref_recruitment_status_changed?: boolean;
  pref_contribution_resolved?: boolean;
  pref_push_enabled?: boolean;
  pref_email_enabled?: boolean;
}

@Controller()
export class NotificationController {
  constructor(
    private readonly svc: NotificationService,
    private readonly prefs: NotificationPreferencesService,
    private readonly deviceTokens: DeviceTokenService,
  ) {}

  @Get('me/notifications')
  list(
    @CurrentUser() user: RequestUser,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
    @Query('unread_only') unreadOnly?: string,
  ) {
    return this.svc.listForUser(user.id, user, {
      cursor,
      limit: limit ? parseInt(limit, 10) : undefined,
      unreadOnly: unreadOnly === 'true',
    });
  }

  @Get('me/notifications/unread-count')
  unreadCount(@CurrentUser() user: RequestUser) {
    return this.svc.getUnreadCount(user.id);
  }

  @Post('me/notifications/read-all')
  @HttpCode(200)
  readAll(@CurrentUser() user: RequestUser) {
    return this.svc.markAllRead(user.id);
  }

  @Post('me/notifications/:id/read')
  @HttpCode(200)
  markRead(@Param('id') id: string, @CurrentUser() user: RequestUser) {
    return this.svc.markRead(id, user.id);
  }

  @Post('me/device-tokens')
  @HttpCode(200)
  registerDeviceToken(
    @CurrentUser() user: RequestUser,
    @Body() body: RegisterDeviceTokenBody,
  ) {
    return this.deviceTokens.register(user.id, {
      provider: body?.provider,
      token: body?.token ?? '',
      platform: body?.platform ?? '',
      appVersion: body?.app_version,
      deviceModel: body?.device_model,
      locale: body?.locale,
    });
  }

  @Delete('me/device-tokens/:token')
  @HttpCode(200)
  revokeDeviceToken(
    @Param('token') token: string,
    @CurrentUser() user: RequestUser,
  ) {
    return this.deviceTokens.revoke(user.id, token);
  }

  @Get('me/notification-preferences')
  getPrefs(@CurrentUser() user: RequestUser) {
    return this.prefs.get(user.id);
  }

  @Patch('me/notification-preferences')
  @HttpCode(200)
  patchPrefs(
    @CurrentUser() user: RequestUser,
    @Body() body: UpdatePrefsBody,
  ) {
    return this.prefs.update(user.id, body ?? {});
  }
}
