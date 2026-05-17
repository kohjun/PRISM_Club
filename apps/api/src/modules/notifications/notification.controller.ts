import {
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { CurrentUser } from '../../shared/decorators/current-user.decorator';
import { RequestUser } from '../../shared/decorators/current-user.decorator';
import { NotificationService } from './notification.service';

@Controller()
export class NotificationController {
  constructor(private readonly svc: NotificationService) {}

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
}
