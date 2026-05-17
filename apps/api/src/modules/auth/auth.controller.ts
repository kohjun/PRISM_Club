import { Body, Controller, Get, HttpCode, Post } from '@nestjs/common';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { Public } from '../../shared/decorators/public.decorator';
import { AuthService } from './auth.service';

interface LoginBody {
  user_id?: string;
}

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Post('login')
  @HttpCode(200)
  login(@Body() body: LoginBody) {
    return this.auth.login(body?.user_id ?? '');
  }

  @Get('session')
  session(@CurrentUser() user: RequestUser) {
    return this.auth.getSessionForUser(user.id);
  }

  /**
   * Server-side logout is a no-op in the alpha JWT design: tokens are
   * stateless and expire on their own. The endpoint exists so clients can
   * call it and clear local storage in a single flow.
   */
  @Post('logout')
  @HttpCode(200)
  logout() {
    return { ok: true };
  }
}
