import {
  BadRequestException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { DeviceTokenDTO } from './dto/notification.dto';

const PLATFORMS = ['ANDROID', 'IOS', 'WEB'] as const;
type Platform = (typeof PLATFORMS)[number];

interface RegisterInput {
  provider?: string;
  token: string;
  platform: string;
  appVersion?: string;
  deviceModel?: string;
  locale?: string;
}

/**
 * Device token bookkeeping for push delivery (P1.2).
 *
 * `register()` is idempotent on (provider, token): a fresh registration from
 * the same device reactivates the row (clears revoked_at, bumps last_seen_at).
 * If the token was previously bound to a different user — e.g. someone signed
 * out, another user signed in on the same device — we transfer ownership so
 * the old owner stops getting that device's pushes.
 */
@Injectable()
export class DeviceTokenService {
  private readonly log = new Logger(DeviceTokenService.name);

  constructor(private readonly prisma: PrismaService) {}

  async register(userId: string, input: RegisterInput): Promise<DeviceTokenDTO> {
    const provider = (input.provider ?? 'FCM').toUpperCase();
    const platformRaw = (input.platform ?? '').toUpperCase();
    if (!PLATFORMS.includes(platformRaw as Platform)) {
      throw new BadRequestException(
        `platform must be one of ${PLATFORMS.join(', ')}`,
      );
    }
    const platform = platformRaw as Platform;
    if (!input.token || input.token.length < 8) {
      throw new BadRequestException('token is required');
    }

    const existing = await this.prisma.deviceToken.findUnique({
      where: { provider_token: { provider, token: input.token } },
    });
    let row;
    if (existing && existing.userId !== userId) {
      this.log.log(
        `device token ownership transfer: ${existing.userId} → ${userId} (provider=${provider})`,
      );
      row = await this.prisma.deviceToken.update({
        where: { id: existing.id },
        data: {
          userId,
          platform,
          appVersion: input.appVersion ?? null,
          deviceModel: input.deviceModel ?? null,
          locale: input.locale ?? null,
          lastSeenAt: new Date(),
          revokedAt: null,
        },
      });
    } else if (existing) {
      row = await this.prisma.deviceToken.update({
        where: { id: existing.id },
        data: {
          platform,
          appVersion: input.appVersion ?? existing.appVersion,
          deviceModel: input.deviceModel ?? existing.deviceModel,
          locale: input.locale ?? existing.locale,
          lastSeenAt: new Date(),
          revokedAt: null,
        },
      });
    } else {
      row = await this.prisma.deviceToken.create({
        data: {
          userId,
          provider,
          token: input.token,
          platform,
          appVersion: input.appVersion ?? null,
          deviceModel: input.deviceModel ?? null,
          locale: input.locale ?? null,
        },
      });
    }
    return this.toDTO(row);
  }

  async revoke(userId: string, token: string): Promise<{ ok: boolean }> {
    if (!token) return { ok: true };
    await this.prisma.deviceToken.updateMany({
      where: { userId, token, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { ok: true };
  }

  /** Internal: fetch active tokens for fan-out. */
  async activeTokensForUser(
    userId: string,
  ): Promise<Array<{ id: string; provider: string; token: string }>> {
    return this.prisma.deviceToken.findMany({
      where: { userId, revokedAt: null },
      select: { id: true, provider: true, token: true },
    });
  }

  /** Internal: called by PushDelivery when the upstream rejects a token. */
  async revokeById(id: string): Promise<void> {
    await this.prisma.deviceToken.update({
      where: { id },
      data: { revokedAt: new Date() },
    });
  }

  private toDTO(row: {
    id: string;
    provider: string;
    platform: string;
    appVersion: string | null;
    deviceModel: string | null;
    locale: string | null;
    lastSeenAt: Date;
  }): DeviceTokenDTO {
    return {
      id: row.id,
      provider: row.provider,
      platform: row.platform,
      app_version: row.appVersion,
      device_model: row.deviceModel,
      locale: row.locale,
      last_seen_at: row.lastSeenAt.toISOString(),
    };
  }
}
