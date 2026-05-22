import { Injectable, Logger } from '@nestjs/common';
import { DeviceTokenService } from '../device-token.service';
import { NotificationPreferencesService } from '../notification-preferences.service';
import {
  DeliveryAttempt,
  DeliveryRequest,
  INotificationDeliverer,
} from './notification-delivery.interface';

/**
 * Push delivery boundary. Activated by `NOTIFICATION_DELIVERY_MODE=push`.
 *
 * Production wiring (the FCM SDK call) lands in a follow-up PR once the
 * Firebase project is provisioned; this version covers everything that does
 * NOT require credentials:
 *
 *   1. Honor `notification_preferences` — master push toggle + per-type bool.
 *   2. Look up active `device_tokens` rows for the recipient.
 *   3. Return a meaningful `SKIPPED`/`SENT` attempt per channel so the
 *      delivery audit log is uniform regardless of mode.
 *
 * Expected env when FCM is wired in:
 *
 *   PUSH_PROVIDER                    "fcm"
 *   FIREBASE_SERVICE_ACCOUNT_JSON    raw JSON (staging)
 *   FIREBASE_SERVICE_ACCOUNT_PATH    path to GCP-mounted secret (prod)
 *   FCM_PROJECT_ID                   project id (informational)
 */
@Injectable()
export class PushDelivery implements INotificationDeliverer {
  private readonly log = new Logger(PushDelivery.name);
  private readonly configured =
    Boolean(process.env.PUSH_PROVIDER) &&
    (Boolean(process.env.FIREBASE_SERVICE_ACCOUNT_JSON) ||
      Boolean(process.env.FIREBASE_SERVICE_ACCOUNT_PATH) ||
      Boolean(process.env.PUSH_SERVICE_ACCOUNT));

  constructor(
    private readonly prefs: NotificationPreferencesService,
    private readonly deviceTokens: DeviceTokenService,
  ) {}

  mode(): string {
    return this.configured
      ? `push(${process.env.PUSH_PROVIDER})`
      : 'push(stub — no provider configured)';
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

    // 3. Final dispatch.
    if (!this.configured) {
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

    // Real FCM dispatch lands in a follow-up PR. Mark as not-yet-implemented
    // so the delivery audit log shows the wire-up gap explicitly.
    this.log.log(
      `PushDelivery would dispatch "${req.type}" to user=${req.userId} via ${process.env.PUSH_PROVIDER} (tokens=${tokens.length})`,
    );
    attempts.push({
      channel: 'PUSH',
      status: 'SKIPPED',
      ref: 'not-implemented',
    });
    return attempts;
  }
}
