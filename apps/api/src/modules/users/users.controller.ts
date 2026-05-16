import { Controller, Get, ForbiddenException } from '@nestjs/common';
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
}
