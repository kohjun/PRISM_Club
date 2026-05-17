import { Controller, Get, HttpCode, Param, Post } from '@nestjs/common';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { FollowService } from './follow.service';

@Controller()
export class FollowController {
  constructor(private readonly svc: FollowService) {}

  @Post('rooms/:slug/follow')
  @HttpCode(200)
  toggle(@Param('slug') slug: string, @CurrentUser() user: RequestUser) {
    return this.svc.toggle(slug, user);
  }

  @Get('rooms/:slug/follow')
  state(@Param('slug') slug: string, @CurrentUser() user: RequestUser) {
    return this.svc.getState(slug, user.id);
  }
}
