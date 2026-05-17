import { Injectable, Logger } from '@nestjs/common';
import {
  DeliveryAttempt,
  DeliveryRequest,
  INotificationDeliverer,
} from './notification-delivery.interface';

/**
 * Push delivery boundary. Activated by `NOTIFICATION_DELIVERY_MODE=push`.
 *
 * Stub today — a future M-? wires FCM / APNS. Expected env shape:
 *
 *   PUSH_PROVIDER          (e.g. "fcm" | "apns")
 *   PUSH_SERVICE_ACCOUNT   (path or JSON, provider-specific)
 *
 * The contract here is identical to EmailDelivery: never throw. Return
 * the attempts list so NotificationService can record what happened.
 */
@Injectable()
export class PushDelivery implements INotificationDeliverer {
  private readonly log = new Logger(PushDelivery.name);
  private readonly configured =
    Boolean(process.env.PUSH_PROVIDER) &&
    Boolean(process.env.PUSH_SERVICE_ACCOUNT);

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
    try {
      if (!this.configured) {
        this.log.debug(
          `PushDelivery stub: would push "${req.type}" to user=${req.userId}`,
        );
        attempts.push({
          channel: 'PUSH',
          status: 'SKIPPED',
          ref: 'no-provider-configured',
        });
      } else {
        this.log.log(
          `PushDelivery would dispatch "${req.type}" to user=${req.userId} via ${process.env.PUSH_PROVIDER}`,
        );
        attempts.push({ channel: 'PUSH', status: 'SKIPPED', ref: 'not-implemented' });
      }
    } catch (e) {
      attempts.push({
        channel: 'PUSH',
        status: 'FAILED',
        error: e instanceof Error ? e.message : String(e),
      });
    }
    return attempts;
  }
}
