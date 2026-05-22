import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Query,
} from '@nestjs/common';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { UserProfileService } from './user-profile.service';
import { UpdateProfileInput } from './dto/user-profile.dto';

@Controller()
export class UserProfileController {
  constructor(private readonly svc: UserProfileService) {}

  @Get('users/:id/profile')
  getProfile(
    @Param('id') id: string,
    @CurrentUser() user: RequestUser,
  ) {
    return this.svc.getProfileBundle(id, user);
  }

  /**
   * P4.5 paginated activity (posts). `type` is reserved for future
   * discriminated-union expansion (contributions / rsvps / reviews);
   * v1 ships posts only.
   */
  @Get('profiles/:id/activity')
  activity(
    @Param('id') id: string,
    @CurrentUser() user: RequestUser,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.svc.listPostsForUser(id, user, {
      cursor,
      limit: limit ? parseInt(limit, 10) : undefined,
    });
  }

  @Patch('me/profile')
  updateMine(
    @CurrentUser() user: RequestUser,
    @Body() body: UpdateProfileInput,
  ) {
    return this.svc.updateMyProfile(user.id, body ?? {});
  }
}
