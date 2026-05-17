import { Controller, Get, Query } from '@nestjs/common';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { HomeService } from './home.service';

@Controller('home')
export class HomeController {
  constructor(private readonly svc: HomeService) {}

  @Get()
  getBundle(@CurrentUser() user: RequestUser) {
    return this.svc.getBundle(user);
  }

  @Get('feed')
  getFeed(
    @CurrentUser() user: RequestUser,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.svc.getHomeFeed(user, cursor, limit ? parseInt(limit, 10) : 20);
  }
}
