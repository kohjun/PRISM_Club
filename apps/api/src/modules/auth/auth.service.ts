import { Injectable, UnauthorizedException } from '@nestjs/common';
import * as jwt from 'jsonwebtoken';
import { PrismaService } from '../../shared/prisma.service';
import { AnalyticsService } from '../analytics/analytics.service';

export interface SessionDTO {
  user_id: string;
  nickname: string | null;
  roles: string[];
  status: string;
  issued_at: string;
  expires_at: string;
}

export interface LoginResultDTO {
  access_token: string;
  session: SessionDTO;
}

export interface JwtPayload {
  sub: string;       // user id
  roles: string[];
  iat: number;
  exp: number;
  jti: string;
}

const TOKEN_TTL_SECONDS = 7 * 24 * 60 * 60; // 7 days

function getSecret(): string {
  return process.env.JWT_SECRET ?? 'prism-club-dev-secret-do-not-use-in-prod';
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly analytics: AnalyticsService,
  ) {}

  /**
   * Passwordless dev/alpha login: the caller submits a user id (one of the
   * seeded persona ids) and gets back a signed JWT. M14+ will replace the
   * mechanism but the surface shape (POST /v1/auth/login → token + session)
   * stays stable.
   */
  async login(userId: string): Promise<LoginResultDTO> {
    if (!userId || typeof userId !== 'string') {
      throw new UnauthorizedException('user_id is required');
    }
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true, roles: true },
    });
    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('Unknown or inactive user');
    }
    const roles = user.roles.map((r) => r.role);
    if (roles.length === 0) roles.push('MEMBER');

    const now = Math.floor(Date.now() / 1000);
    const exp = now + TOKEN_TTL_SECONDS;
    const jti = `${user.id}-${now}`;

    const payload: JwtPayload = {
      sub: user.id,
      roles,
      iat: now,
      exp,
      jti,
    };

    const token = jwt.sign(payload, getSecret(), { algorithm: 'HS256' });

    this.analytics.record({
      actorId: user.id,
      eventType: 'AUTH_LOGIN',
      payload: { roles_count: roles.length },
    });

    return {
      access_token: token,
      session: {
        user_id: user.id,
        nickname: user.profile?.nickname ?? null,
        roles,
        status: user.status,
        issued_at: new Date(now * 1000).toISOString(),
        expires_at: new Date(exp * 1000).toISOString(),
      },
    };
  }

  /**
   * Verify a Bearer token and return the contained payload. Throws
   * UnauthorizedException on any failure (invalid signature, expired, etc.).
   */
  verify(token: string): JwtPayload {
    try {
      const decoded = jwt.verify(token, getSecret(), {
        algorithms: ['HS256'],
      }) as JwtPayload;
      if (!decoded.sub || !Array.isArray(decoded.roles)) {
        throw new UnauthorizedException('Malformed token');
      }
      return decoded;
    } catch (e) {
      if (e instanceof jwt.TokenExpiredError) {
        throw new UnauthorizedException('Token expired');
      }
      if (e instanceof jwt.JsonWebTokenError) {
        throw new UnauthorizedException('Invalid token');
      }
      throw e;
    }
  }

  async getSessionForUser(userId: string): Promise<SessionDTO> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true, roles: true },
    });
    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('Session user not found');
    }
    const roles = user.roles.map((r) => r.role);
    if (roles.length === 0) roles.push('MEMBER');

    const now = Math.floor(Date.now() / 1000);
    return {
      user_id: user.id,
      nickname: user.profile?.nickname ?? null,
      roles,
      status: user.status,
      issued_at: new Date(now * 1000).toISOString(),
      expires_at: new Date((now + TOKEN_TTL_SECONDS) * 1000).toISOString(),
    };
  }
}
