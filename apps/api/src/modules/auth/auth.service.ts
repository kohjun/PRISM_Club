import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import * as crypto from 'crypto';
import * as jwt from 'jsonwebtoken';
import { hash as argonHash, verify as argonVerify } from '@node-rs/argon2';
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
  refresh_token: string;
  session: SessionDTO;
}

export interface JwtPayload {
  sub: string;
  roles: string[];
  iat: number;
  exp: number;
  jti: string;
  /**
   * Token flavor. New tokens issued by P1.1+ always declare `typ:'access'` so
   * an attacker can't replay an opaque refresh string in the Authorization
   * header. Pre-P1.1 tokens have no `typ` and are still accepted until they
   * expire (they all roll off within JWT_ACCESS_TTL_SECONDS of cutover).
   */
  typ?: 'access';
}

const DEFAULT_ACCESS_TTL_SECONDS = 15 * 60;
const DEFAULT_REFRESH_TTL_SECONDS = 30 * 24 * 60 * 60;
const OAUTH_STATE_TTL_MS = 10 * 60 * 1000;

function getSecret(): string {
  return process.env.JWT_SECRET ?? 'prism-club-dev-secret-do-not-use-in-prod';
}

function getAccessTtl(): number {
  const raw = parseInt(process.env.JWT_ACCESS_TTL_SECONDS ?? '', 10);
  return Number.isFinite(raw) && raw > 0 ? raw : DEFAULT_ACCESS_TTL_SECONDS;
}

function getRefreshTtl(): number {
  const raw = parseInt(process.env.JWT_REFRESH_TTL_SECONDS ?? '', 10);
  return Number.isFinite(raw) && raw > 0 ? raw : DEFAULT_REFRESH_TTL_SECONDS;
}

/**
 * Dev passwordless login gate. Defaults:
 *   - production: off unless ALLOW_DEV_LOGIN=1 (must be explicit)
 *   - staging/dev/test: on unless ALLOW_DEV_LOGIN=0 (keeps smoke + e2e working)
 */
export function isDevLoginEnabled(): boolean {
  const env = process.env.NODE_ENV;
  const flag = process.env.ALLOW_DEV_LOGIN;
  if (env === 'production') {
    return flag === '1';
  }
  return flag !== '0';
}

function getKakaoConfig(): {
  clientId: string;
  redirectUri: string;
  clientSecret?: string;
} {
  const clientId = process.env.KAKAO_REST_API_KEY ?? '';
  const redirectUri = process.env.KAKAO_REDIRECT_URI ?? '';
  if (!clientId || !redirectUri) {
    throw new BadRequestException(
      'Kakao OAuth is not configured on this server',
    );
  }
  return {
    clientId,
    redirectUri,
    clientSecret: process.env.KAKAO_CLIENT_SECRET || undefined,
  };
}

function sha256Hex(input: string): string {
  return crypto.createHash('sha256').update(input).digest('hex');
}

function randomToken(byteLength = 32): string {
  return crypto.randomBytes(byteLength).toString('base64url');
}

function isEmail(s: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
}

type UserWithProfileAndRoles = {
  id: string;
  status: string;
  oauthProvider: string | null;
  profile: { nickname: string | null } | null;
  roles: { role: string }[];
};

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly analytics: AnalyticsService,
  ) {}

  /**
   * Passwordless dev/alpha login — caller submits a seeded user_id and gets a
   * signed token pair. Gated by `ALLOW_DEV_LOGIN=1` so production deploys can
   * disable it with one env flip; the controller maps the disabled case to
   * 410 GONE.
   */
  async login(userId: string): Promise<LoginResultDTO> {
    if (!isDevLoginEnabled()) {
      throw new UnauthorizedException('Dev passwordless login is disabled');
    }
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
    return this.issueTokenPairForUser(user, { source: 'DEV' });
  }

  async signupWithEmail(input: {
    email: string;
    password: string;
    nickname: string;
  }): Promise<LoginResultDTO> {
    const email = (input.email ?? '').trim().toLowerCase();
    const password = input.password ?? '';
    const nickname = (input.nickname ?? '').trim();
    if (!isEmail(email)) {
      throw new BadRequestException('Invalid email');
    }
    if (password.length < 8) {
      throw new BadRequestException('Password must be at least 8 characters');
    }
    if (nickname.length < 2 || nickname.length > 24) {
      throw new BadRequestException('Nickname must be 2-24 characters');
    }

    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) {
      throw new BadRequestException('Email already registered');
    }
    const nicknameExists = await this.prisma.profile.findUnique({
      where: { nickname },
    });
    if (nicknameExists) {
      throw new BadRequestException('Nickname already taken');
    }

    const passwordHash = await argonHash(password);

    const created = await this.prisma.$transaction(async (tx) => {
      const u = await tx.user.create({
        data: {
          email,
          passwordHash,
          oauthProvider: 'EMAIL',
          status: 'ACTIVE',
        },
      });
      await tx.profile.create({
        data: { userId: u.id, nickname },
      });
      return tx.user.findUniqueOrThrow({
        where: { id: u.id },
        include: { profile: true, roles: true },
      });
    });

    this.analytics.record({
      actorId: created.id,
      eventType: 'AUTH_SIGNUP',
      payload: { provider: 'EMAIL' },
    });
    return this.issueTokenPairForUser(created, { source: 'EMAIL' });
  }

  async loginWithEmail(input: {
    email: string;
    password: string;
  }): Promise<LoginResultDTO> {
    const email = (input.email ?? '').trim().toLowerCase();
    const password = input.password ?? '';
    if (!email || !password) {
      throw new UnauthorizedException('Invalid credentials');
    }
    const user = await this.prisma.user.findUnique({
      where: { email },
      include: { profile: true, roles: true },
    });
    if (!user || user.status !== 'ACTIVE' || !user.passwordHash) {
      throw new UnauthorizedException('Invalid credentials');
    }
    const ok = await argonVerify(user.passwordHash, password);
    if (!ok) {
      throw new UnauthorizedException('Invalid credentials');
    }
    return this.issueTokenPairForUser(user, { source: 'EMAIL' });
  }

  /**
   * Build the Kakao authorization URL with PKCE + CSRF state. The state row
   * holds the code_verifier and a nonce; the caller stores `state` and ships
   * it back via the callback so we can re-derive code_verifier server-side.
   */
  async kakaoAuthorizeUrl(input: {
    redirectTo?: string;
  }): Promise<{ url: string; state: string }> {
    const cfg = getKakaoConfig();
    const state = randomToken(24);
    const codeVerifier = randomToken(32);
    const codeChallenge = crypto
      .createHash('sha256')
      .update(codeVerifier)
      .digest('base64url');
    const nonce = randomToken(16);

    await this.prisma.oAuthState.create({
      data: {
        state,
        codeVerifier,
        nonce,
        redirectTo: input.redirectTo ?? null,
        expiresAt: new Date(Date.now() + OAUTH_STATE_TTL_MS),
      },
    });

    const url =
      `https://kauth.kakao.com/oauth/authorize` +
      `?response_type=code` +
      `&client_id=${encodeURIComponent(cfg.clientId)}` +
      `&redirect_uri=${encodeURIComponent(cfg.redirectUri)}` +
      `&state=${encodeURIComponent(state)}` +
      `&code_challenge=${encodeURIComponent(codeChallenge)}` +
      `&code_challenge_method=S256`;
    return { url, state };
  }

  async loginWithKakao(input: {
    code: string;
    state: string;
  }): Promise<LoginResultDTO> {
    const cfg = getKakaoConfig();
    const code = (input.code ?? '').trim();
    const state = (input.state ?? '').trim();
    if (!code || !state) {
      throw new BadRequestException('Missing code/state');
    }
    const oauthState = await this.prisma.oAuthState.findUnique({
      where: { state },
    });
    if (!oauthState || oauthState.expiresAt < new Date()) {
      throw new UnauthorizedException('OAuth state expired or unknown');
    }
    // One-shot consumption to defeat replay.
    await this.prisma.oAuthState.delete({ where: { state } });

    const tokenResp = await fetch('https://kauth.kakao.com/oauth/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8',
      },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        client_id: cfg.clientId,
        redirect_uri: cfg.redirectUri,
        code,
        code_verifier: oauthState.codeVerifier,
        ...(cfg.clientSecret ? { client_secret: cfg.clientSecret } : {}),
      }).toString(),
    });
    if (!tokenResp.ok) {
      throw new UnauthorizedException('Kakao token exchange failed');
    }
    const tokenJson = (await tokenResp.json()) as { access_token?: string };
    if (!tokenJson.access_token) {
      throw new UnauthorizedException('Kakao did not return access_token');
    }

    const meResp = await fetch('https://kapi.kakao.com/v2/user/me', {
      headers: { Authorization: `Bearer ${tokenJson.access_token}` },
    });
    if (!meResp.ok) {
      throw new UnauthorizedException('Kakao /user/me failed');
    }
    const meJson = (await meResp.json()) as {
      id?: number;
      kakao_account?: { email?: string };
      properties?: { nickname?: string };
    };
    const kakaoId = meJson.id ? String(meJson.id) : '';
    if (!kakaoId) {
      throw new UnauthorizedException('Kakao user id missing');
    }
    const kakaoEmail = meJson.kakao_account?.email ?? null;
    const kakaoNickname =
      meJson.properties?.nickname ?? `kakao_${kakaoId.slice(-6)}`;

    let user: UserWithProfileAndRoles | null =
      await this.prisma.user.findFirst({
        where: { oauthProvider: 'KAKAO', oauthId: kakaoId },
        include: { profile: true, roles: true },
      });
    if (!user) {
      const nickname = await this.ensureUniqueNickname(kakaoNickname);
      user = await this.prisma.$transaction(async (tx) => {
        const u = await tx.user.create({
          data: {
            email: kakaoEmail ?? undefined,
            oauthProvider: 'KAKAO',
            oauthId: kakaoId,
            status: 'ACTIVE',
          },
        });
        await tx.profile.create({ data: { userId: u.id, nickname } });
        return tx.user.findUniqueOrThrow({
          where: { id: u.id },
          include: { profile: true, roles: true },
        });
      });
      this.analytics.record({
        actorId: user.id,
        eventType: 'AUTH_SIGNUP',
        payload: { provider: 'KAKAO' },
      });
    }
    return this.issueTokenPairForUser(user, { source: 'KAKAO' });
  }

  /**
   * Rotate a refresh token. On reuse (the row was already revoked) the entire
   * family is killed — this is the canonical defense against refresh-token
   * theft. Successful rotation marks the current row revoked and issues a new
   * pair on the same family_id.
   */
  async rotateRefreshToken(
    rawRefresh: string,
    opts: { userAgent?: string; ip?: string } = {},
  ): Promise<LoginResultDTO> {
    const tokenHash = sha256Hex(rawRefresh ?? '');
    if (!rawRefresh || !tokenHash) {
      throw new UnauthorizedException('Missing refresh token');
    }
    const row = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
    });
    if (!row) {
      throw new UnauthorizedException('Unknown refresh token');
    }
    if (row.revokedAt) {
      await this.prisma.refreshToken.updateMany({
        where: { familyId: row.familyId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      throw new UnauthorizedException(
        'Refresh token reuse detected — family revoked',
      );
    }
    if (row.expiresAt < new Date()) {
      throw new UnauthorizedException('Refresh token expired');
    }
    await this.prisma.refreshToken.update({
      where: { id: row.id },
      data: { revokedAt: new Date() },
    });
    const user = await this.prisma.user.findUnique({
      where: { id: row.userId },
      include: { profile: true, roles: true },
    });
    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('User not found or inactive');
    }
    const source =
      user.oauthProvider === 'KAKAO'
        ? 'KAKAO'
        : user.oauthProvider === 'DEV'
          ? 'DEV'
          : 'EMAIL';
    return this.issueTokenPairForUser(user, {
      source,
      userAgent: opts.userAgent,
      ip: opts.ip,
      familyId: row.familyId,
    });
  }

  async revokeRefreshToken(rawRefresh: string): Promise<{ ok: boolean }> {
    const tokenHash = sha256Hex(rawRefresh ?? '');
    if (!rawRefresh || !tokenHash) {
      return { ok: true };
    }
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { ok: true };
  }

  async revokeAllForUser(
    userId: string,
  ): Promise<{ revoked_count: number }> {
    const res = await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { revoked_count: res.count };
  }

  verify(token: string): JwtPayload {
    try {
      const decoded = jwt.verify(token, getSecret(), {
        algorithms: ['HS256'],
      }) as JwtPayload;
      if (!decoded.sub || !Array.isArray(decoded.roles)) {
        throw new UnauthorizedException('Malformed token');
      }
      if (decoded.typ !== undefined && decoded.typ !== 'access') {
        throw new UnauthorizedException('Token type not allowed');
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
    const accessTtl = getAccessTtl();
    return {
      user_id: user.id,
      nickname: user.profile?.nickname ?? null,
      roles,
      status: user.status,
      issued_at: new Date(now * 1000).toISOString(),
      expires_at: new Date((now + accessTtl) * 1000).toISOString(),
    };
  }

  private async issueTokenPairForUser(
    user: UserWithProfileAndRoles,
    opts: {
      source: 'DEV' | 'EMAIL' | 'KAKAO';
      userAgent?: string;
      ip?: string;
      familyId?: string;
    },
  ): Promise<LoginResultDTO> {
    const roles = user.roles.map((r) => r.role);
    if (roles.length === 0) roles.push('MEMBER');

    const now = Math.floor(Date.now() / 1000);
    const accessTtl = getAccessTtl();
    const refreshTtl = getRefreshTtl();
    const jti = `${user.id}-${now}-${randomToken(4)}`;

    const accessPayload: JwtPayload = {
      sub: user.id,
      roles,
      iat: now,
      exp: now + accessTtl,
      jti,
      typ: 'access',
    };
    const accessToken = jwt.sign(accessPayload, getSecret(), {
      algorithm: 'HS256',
    });

    const rawRefresh = randomToken(32);
    const familyId = opts.familyId ?? crypto.randomUUID();
    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: sha256Hex(rawRefresh),
        familyId,
        userAgent: opts.userAgent ?? null,
        ip: opts.ip ?? null,
        expiresAt: new Date((now + refreshTtl) * 1000),
      },
    });

    this.analytics.record({
      actorId: user.id,
      eventType: 'AUTH_LOGIN',
      payload: { roles_count: roles.length, source: opts.source },
    });

    return {
      access_token: accessToken,
      refresh_token: rawRefresh,
      session: {
        user_id: user.id,
        nickname: user.profile?.nickname ?? null,
        roles,
        status: user.status,
        issued_at: new Date(now * 1000).toISOString(),
        expires_at: new Date((now + accessTtl) * 1000).toISOString(),
      },
    };
  }

  private async ensureUniqueNickname(base: string): Promise<string> {
    const cleaned =
      base.trim().replace(/\s+/g, '_').slice(0, 18) || 'user';
    let candidate = cleaned;
    for (let attempt = 0; attempt < 10; attempt += 1) {
      const taken = await this.prisma.profile.findUnique({
        where: { nickname: candidate },
      });
      if (!taken) return candidate;
      candidate = `${cleaned}_${crypto.randomBytes(2).toString('hex')}`;
    }
    return `${cleaned}_${crypto.randomBytes(4).toString('hex')}`;
  }
}
