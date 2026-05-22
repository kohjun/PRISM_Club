import {
  Body,
  Controller,
  Get,
  GoneException,
  HttpCode,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { Public } from '../../shared/decorators/public.decorator';
import { AuthService, isDevLoginEnabled } from './auth.service';

interface LoginBody {
  user_id?: string;
}

interface EmailLoginBody {
  email?: string;
  password?: string;
}

interface SignupBody {
  email?: string;
  password?: string;
  nickname?: string;
}

interface RefreshBody {
  refresh_token?: string;
}

interface LogoutBody {
  refresh_token?: string;
  all_devices?: boolean;
}

interface KakaoCallbackQuery {
  code?: string;
  state?: string;
}

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  /**
   * Legacy dev/alpha login (user_id → tokens). Disabled by default in
   * P1.1+ deployments: the operator opts in with `ALLOW_DEV_LOGIN=1`.
   * When disabled, returns 410 GONE so smoke scripts fail fast instead
   * of silently authenticating against a stale path.
   */
  @Public()
  @Post('login')
  @HttpCode(200)
  login(@Body() body: LoginBody) {
    if (!isDevLoginEnabled()) {
      throw new GoneException(
        'Dev passwordless login is disabled — use /auth/login/email or /auth/oauth/kakao/*',
      );
    }
    return this.auth.login(body?.user_id ?? '');
  }

  @Public()
  @Post('signup')
  @HttpCode(200)
  signupWithEmail(@Body() body: SignupBody) {
    return this.auth.signupWithEmail({
      email: body?.email ?? '',
      password: body?.password ?? '',
      nickname: body?.nickname ?? '',
    });
  }

  @Public()
  @Post('login/email')
  @HttpCode(200)
  loginWithEmail(@Body() body: EmailLoginBody) {
    return this.auth.loginWithEmail({
      email: body?.email ?? '',
      password: body?.password ?? '',
    });
  }

  @Public()
  @Get('oauth/kakao/authorize')
  kakaoAuthorize(@Query('redirect_to') redirectTo?: string) {
    return this.auth.kakaoAuthorizeUrl({ redirectTo });
  }

  @Public()
  @Get('oauth/kakao/callback')
  @HttpCode(200)
  loginWithKakao(@Query() query: KakaoCallbackQuery) {
    return this.auth.loginWithKakao({
      code: query?.code ?? '',
      state: query?.state ?? '',
    });
  }

  @Public()
  @Post('refresh')
  @HttpCode(200)
  refresh(
    @Body() body: RefreshBody,
    @Req() req: { headers: Record<string, string | undefined>; ip?: string },
  ) {
    return this.auth.rotateRefreshToken(body?.refresh_token ?? '', {
      userAgent: req?.headers?.['user-agent'],
      ip: req?.ip,
    });
  }

  @Get('session')
  session(@CurrentUser() user: RequestUser) {
    return this.auth.getSessionForUser(user.id);
  }

  /**
   * Logout. Two modes:
   *   - `{ refresh_token }`         → revoke that single device's refresh token
   *   - `{ all_devices: true }`     → revoke every refresh token for the
   *                                   authenticated user (Authorization header
   *                                   with a valid access JWT required)
   * Stateless access JWTs still expire on their own, but the client should
   * drop them locally on logout.
   */
  @Public()
  @Post('logout')
  @HttpCode(200)
  async logout(
    @Body() body: LogoutBody,
    @Req() req: { headers: Record<string, string | undefined> },
  ) {
    if (body?.all_devices) {
      const authHeader = req?.headers?.['authorization'];
      if (
        typeof authHeader === 'string' &&
        authHeader.startsWith('Bearer ')
      ) {
        const payload = this.auth.verify(authHeader.slice(7).trim());
        return this.auth.revokeAllForUser(payload.sub);
      }
      // Without a valid access token we cannot identify the user — fall
      // through to the no-op so clients can still clear local state.
    }
    if (body?.refresh_token) {
      return this.auth.revokeRefreshToken(body.refresh_token);
    }
    return { ok: true };
  }
}
