import { Controller, Get, Param, Post } from '@nestjs/common';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { UserFollowService } from './user-follow.service';

@Controller('users/:id')
export class UserFollowController {
  constructor(private readonly svc: UserFollowService) {}

  @Post('follow-toggle')
  toggle(@Param('id') id: string, @CurrentUser() user: RequestUser) {
    return this.svc.toggle(id, user.id);
  }

  @Get('follow-state')
  getState(@Param('id') id: string, @CurrentUser() user: RequestUser) {
    return this.svc.getState(id, user.id);
  }
}
