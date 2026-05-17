import { Body, Controller, Get, Param, Patch } from '@nestjs/common';
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

  @Patch('me/profile')
  updateMine(
    @CurrentUser() user: RequestUser,
    @Body() body: UpdateProfileInput,
  ) {
    return this.svc.updateMyProfile(user.id, body ?? {});
  }
}
