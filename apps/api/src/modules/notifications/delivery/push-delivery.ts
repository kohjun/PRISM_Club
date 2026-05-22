import { Injectable, Logger } from '@nestjs/common';
import * as admin from 'firebase-admin';
import * as fs from 'fs';
import { DeviceTokenService } from '../device-token.service';
import { NotificationPreferencesService } from '../notification-preferences.service';
import { MetricsService } from '../../../shared/metrics.service';
import {
  DeliveryAttempt,
  DeliveryRequest,
  INotificationDeliverer,
} from './notification-delivery.interface';

/**
 * Push delivery via Firebase Cloud Messaging.
 *
 * Activated by `NOTIFICATION_DELIVERY_MODE=push`. Service-account credentials
 * are loaded from either `FIREBASE_SERVICE_ACCOUNT_JSON` (raw JSON; staging
 * convenience) or `FIREBASE_SERVICE_ACCOUNT_PATH` (mounted secret; preferred
 * in prod). Backward-compatible aliases `PUSH_PROVIDER` and
 * `PUSH_SERVICE_ACCOUNT` are still recognized.
 *
 * Delivery responsibilities:
 *   1. Honor notification_preferences (master push toggle + per-type bool).
 *   2. Look up active device_tokens for the recipient.
 *   3. Send a multicast via FCM v1.
 *   4. Revoke any token FCM reports as InvalidRegistration / NotRegistered.
 *
 * The Firebase Admin SDK is initialised lazily on the first delivery so an
 * API boot with no credentials still succeeds (the deliverer just stays in
 * stub mode and reports SKIPPED(no-provider-configured)).
 */
@Injectable()
export class PushDelivery implements INotificationDeliverer {
  private readonly log = new Logger(PushDelivery.name);
  private app: admin.app.App | null = null;
  private appInitError: string | null = null;

  constructor(
    private readonly prefs: NotificationPreferencesService,
    private readonly deviceTokens: DeviceTokenService,
    private readonly metrics: MetricsService,
  ) {}

  mode(): string {
    if (!this.hasCredentialsEnv()) {
      return 'push(stub — no provider configured)';
    }
    return `push(fcm)`;
  }

  async deliver(req: DeliveryRequest): Promise<DeliveryAttempt[]> {
    const attempts: DeliveryAttempt[] = [
      { channel: 'IN_APP', status: 'SENT', ref: req.notificationId },
      { channel: 'EMAIL', status: 'SKIPPED' },
    ];

    // 1. Per-user preference gate.
    const gate = await this.prefs.pushAllowedFor(req.userId, req.type);
    if (!gate.allow) {
      attempts.push({
        channel: 'PUSH',
        status: 'SKIPPED',
        ref: gate.reason ?? 'user-pref-off',
      });
      return attempts;
    }

    // 2. Recipient must have at least one active token.
    const tokens = await this.deviceTokens.activeTokensForUser(req.userId);
    if (tokens.length === 0) {
      attempts.push({
        channel: 'PUSH',
        status: 'SKIPPED',
        ref: 'no-active-device-tokens',
      });
      return attempts;
    }

    // 3. Credentials present?
    if (!this.hasCredentialsEnv()) {
      this.log.debug(
        `PushDelivery stub: would push "${req.type}" to user=${req.userId} (tokens=${tokens.length})`,
      );
      attempts.push({
        channel: 'PUSH',
        status: 'SKIPPED',
        ref: 'no-provider-configured',
      });
      return attempts;
    }

    // 4. Ensure the FCM app is initialised (lazy).
    const app = this.ensureFirebaseApp();
    if (!app) {
      attempts.push({
        channel: 'PUSH',
        status: 'FAILED',
        error: this.appInitError ?? 'firebase-admin init failed',
      });
      return attempts;
    }

    // 5. Build + send.
    const fcmTokens = tokens
      .filter((t) => t.provider.toUpperCase() === 'FCM')
      .map((t) => t.token);
    if (fcmTokens.length === 0) {
      attempts.push({
        channel: 'PUSH',
        status: 'SKIPPED',
        ref: 'no-fcm-tokens',
      });
      return attempts;
    }

    const copy = notificationCopyFor(req.type, req.payload);
    const deepLink = derivedDeepLink(req.payload);

    try {
      const response = await admin
        .messaging(app)
        .sendEachForMulticast({
          tokens: fcmTokens,
          notification: { title: copy.title, body: copy.body },
          data: {
            type: req.type,
            notification_id: req.notificationId,
            ...(deepLink ? { deep_link: deepLink } : {}),
          },
          android: {
            notification: { channelId: 'prism_default' },
            priority: 'high',
          },
        });

      // Revoke tokens FCM rejects so we don't keep retrying dead devices.
      const responsesByToken = response.responses.map((r, i) => ({
        token: fcmTokens[i],
        r,
      }));
      const failed = responsesByToken.filter((x) => !x.r.success);
      for (const f of failed) {
        const code = f.r.error?.code ?? '';
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/invalid-argument'
        ) {
          const row = tokens.find((t) => t.token === f.token);
          if (row) {
            await this.deviceTokens.revokeById(row.id).catch((e) => {
              this.log.warn(
                `failed to revoke device token id=${row.id}: ${e instanceof Error ? e.message : String(e)}`,
              );
            });
          }
        }
      }

      if (response.successCount > 0) {
        this.metrics.record('notification.push.sent', response.successCount);
        attempts.push({
          channel: 'PUSH',
          status: 'SENT',
          ref: `fcm:${response.successCount}/${fcmTokens.length}`,
        });
      } else {
        this.metrics.inc('notification.push.failed');
        attempts.push({
          channel: 'PUSH',
          status: 'FAILED',
          error:
            response.responses
              .map((r) => r.error?.code ?? r.error?.message ?? 'unknown')
              .find(Boolean) ?? 'all-tokens-rejected',
        });
      }
    } catch (e) {
      this.metrics.inc('notification.push.failed');
      attempts.push({
        channel: 'PUSH',
        status: 'FAILED',
        error: e instanceof Error ? e.message : String(e),
      });
    }
    return attempts;
  }

  private hasCredentialsEnv(): boolean {
    return Boolean(
      process.env.FIREBASE_SERVICE_ACCOUNT_JSON ||
        process.env.FIREBASE_SERVICE_ACCOUNT_PATH ||
        // Backward-compat aliases from the original stub.
        process.env.PUSH_SERVICE_ACCOUNT,
    );
  }

  private ensureFirebaseApp(): admin.app.App | null {
    if (this.app) return this.app;
    if (this.appInitError) return null;

    try {
      const credentials = this.loadServiceAccount();
      if (!credentials) {
        this.appInitError = 'service account env missing';
        return null;
      }
      // Use a named app so multiple init() calls in unit tests don't clash.
      const name = 'prism-push';
      const existing = admin
        .apps
        .find((a) => a !== null && a.name === name);
      this.app =
        existing ??
        admin.initializeApp(
          { credential: admin.credential.cert(credentials) },
          name,
        );
      return this.app;
    } catch (e) {
      this.appInitError = e instanceof Error ? e.message : String(e);
      this.log.error(
        `firebase-admin initializeApp failed: ${this.appInitError}`,
      );
      return null;
    }
  }

  private loadServiceAccount(): admin.ServiceAccount | null {
    const rawJson =
      process.env.FIREBASE_SERVICE_ACCOUNT_JSON ??
      process.env.PUSH_SERVICE_ACCOUNT;
    if (rawJson && rawJson.trim().startsWith('{')) {
      const parsed = JSON.parse(rawJson) as Record<string, unknown>;
      return {
        projectId: parsed.project_id as string,
        clientEmail: parsed.client_email as string,
        privateKey: parsed.private_key as string,
      };
    }
    const path =
      process.env.FIREBASE_SERVICE_ACCOUNT_PATH ??
      (rawJson && !rawJson.trim().startsWith('{') ? rawJson : undefined);
    if (path) {
      const contents = fs.readFileSync(path, 'utf-8');
      const parsed = JSON.parse(contents) as Record<string, unknown>;
      return {
        projectId: parsed.project_id as string,
        clientEmail: parsed.client_email as string,
        privateKey: parsed.private_key as string,
      };
    }
    return null;
  }
}

/**
 * Korean copy table. Plain server-side i18n — payloads carry IDs only,
 * never user-generated content beyond the actor's nickname.
 */
function notificationCopyFor(
  type: string,
  payload: Record<string, unknown>,
): { title: string; body: string } {
  const actor = (payload?.['actorNickname'] as string | undefined) ?? '누군가';
  switch (type) {
    case 'REPLY_ON_POST':
      return { title: '새 댓글', body: `${actor}님이 내 글에 댓글을 남겼어요.` };
    case 'NESTED_REPLY':
      return {
        title: '답글',
        body: `${actor}님이 내 댓글에 답글을 남겼어요.`,
      };
    case 'NEW_POST_IN_FOLLOWED_ROOM':
      return {
        title: '팔로우한 방의 새 글',
        body: `${actor}님이 새 글을 올렸어요.`,
      };
    case 'RECRUITMENT_STATUS_CHANGED':
      return {
        title: '모집 상태 변경',
        body: '내 모집글 상태가 바뀌었어요.',
      };
    case 'CONTRIBUTION_RESOLVED':
      return {
        title: '지식 기여 검수 결과',
        body: `${actor} 큐레이터가 내 제안을 검토했어요.`,
      };
    default:
      return { title: 'PRISM Club', body: '새 알림이 있어요.' };
  }
}

function derivedDeepLink(
  payload: Record<string, unknown>,
): string | null {
  const postId = payload?.['postId'] as string | undefined;
  const roomSlug = payload?.['roomSlug'] as string | undefined;
  const eventCardId = payload?.['eventCardId'] as string | undefined;
  if (postId) return `/posts/${postId}`;
  if (eventCardId) return `/events/${eventCardId}`;
  if (roomSlug) return `/rooms/${roomSlug}`;
  return null;
}
