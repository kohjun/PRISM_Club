import {
  Controller,
  ForbiddenException,
  Get,
  Query,
} from '@nestjs/common';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { Public } from '../../shared/decorators/public.decorator';
import { UsersService } from './users.service';

@Controller()
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  async getMe(@CurrentUser() user: RequestUser) {
    return this.users.getMe(user.id);
  }

  @Public()
  @Get('dev/users')
  async listDevUsers() {
    if (process.env.NODE_ENV === 'production') {
      throw new ForbiddenException('dev endpoints are disabled in production');
    }
    return this.users.listDevUsers();
  }

  /**
   * P6.1: mention autocomplete. `q` is a nickname prefix (case
   * insensitive). Hard cap at 8 results so the composer dropdown
   * stays bounded. Authenticated to prevent open scraping.
   */
  @Get('users/search')
  async searchByNickname(@Query('q') q?: string) {
    return { items: await this.users.searchByNickname(q ?? '') };
  }
}
