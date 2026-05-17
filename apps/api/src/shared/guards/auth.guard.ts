import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { PrismaService } from '../prisma.service';
import { AuthService } from '../../modules/auth/auth.service';

/// Accepts EITHER:
///   - `Authorization: Bearer <jwt>` (M13+, normal Flutter / production)
///   - `X-User-Id: <uuid>` (dev/test/smoke convenience — only when
///     ALLOW_X_USER_ID=1 OR NODE_ENV !== 'production')
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
    private readonly auth: AuthService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);
    if (isPublic) {
      return true;
    }

    const req = ctx.switchToHttp().getRequest();

    // 1. Try Authorization: Bearer <jwt> first (preferred, real session).
    const authHeader = req.headers['authorization'];
    if (typeof authHeader === 'string' && authHeader.startsWith('Bearer ')) {
      const token = authHeader.slice(7).trim();
      const payload = this.auth.verify(token);
      req.user = await this.resolveUser(payload.sub);
      return true;
    }

    // 2. Fallback to X-User-Id (dev/test/smoke only).
    const allowXUserId =
      process.env.ALLOW_X_USER_ID === '1' ||
      process.env.NODE_ENV !== 'production';
    const headerUserId = req.headers['x-user-id'];
    if (
      allowXUserId &&
      typeof headerUserId === 'string' &&
      headerUserId.length > 0
    ) {
      req.user = await this.resolveUser(headerUserId);
      return true;
    }

    throw new UnauthorizedException(
      'Authentication required (Bearer token, or X-User-Id in dev mode)',
    );
  }

  private async resolveUser(
    userId: string,
  ): Promise<{ id: string; status: string; roles: string[] }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { roles: true },
    });

    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('User not found or inactive');
    }

    const roles = user.roles.map((r) => r.role);
    if (roles.length === 0) {
      roles.push('MEMBER');
    }
    return { id: user.id, status: user.status, roles };
  }
}
