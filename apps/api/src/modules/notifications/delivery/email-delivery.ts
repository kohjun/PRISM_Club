import { Injectable, Logger } from '@nestjs/common';
import {
  DeliveryAttempt,
  DeliveryRequest,
  INotificationDeliverer,
} from './notification-delivery.interface';

/**
 * Email delivery boundary. Activated by `NOTIFICATION_DELIVERY_MODE=email`.
 *
 * The bundled implementation is INERT — it logs the email it would have
 * sent and returns SKIPPED. A future M-? hooks this up to a real provider
 * (SES, Resend, Postmark, ...). Once that lands, expected env shape:
 *
 *   EMAIL_PROVIDER         (e.g. "ses" | "resend" | "smtp")
 *   EMAIL_FROM_ADDRESS     ("PRISM Club <no-reply@…>")
 *   EMAIL_API_KEY          (provider-specific secret)
 *   EMAIL_REGION           (provider-specific, e.g. "ap-northeast-2")
 *
 * Errors here MUST be caught and returned as FAILED — never thrown.
 * NotificationService relies on this contract to keep DB writes safe.
 */
@Injectable()
export class EmailDelivery implements INotificationDeliverer {
  private readonly log = new Logger(EmailDelivery.name);
  private readonly providerConfigured =
    Boolean(process.env.EMAIL_PROVIDER) &&
    Boolean(process.env.EMAIL_FROM_ADDRESS);

  mode(): string {
    return this.providerConfigured
      ? `email(${process.env.EMAIL_PROVIDER})`
      : 'email(stub — no provider configured)';
  }

  async deliver(req: DeliveryRequest): Promise<DeliveryAttempt[]> {
    const attempts: DeliveryAttempt[] = [
      { channel: 'IN_APP', status: 'SENT', ref: req.notificationId },
    ];
    try {
      if (!this.providerConfigured) {
        this.log.debug(
          `EmailDelivery stub: would send "${req.type}" to user=${req.userId}`,
        );
        attempts.push({
          channel: 'EMAIL',
          status: 'SKIPPED',
          ref: 'no-provider-configured',
        });
      } else {
        // Real send goes here. We deliberately don't implement SMTP /
        // provider HTTP in this alpha — the boundary + status contract
        // is what matters.
        this.log.log(
          `EmailDelivery would dispatch "${req.type}" to user=${req.userId} via ${process.env.EMAIL_PROVIDER}`,
        );
        attempts.push({ channel: 'EMAIL', status: 'SKIPPED', ref: 'not-implemented' });
      }
    } catch (e) {
      attempts.push({
        channel: 'EMAIL',
        status: 'FAILED',
        error: e instanceof Error ? e.message : String(e),
      });
    }
    attempts.push({ channel: 'PUSH', status: 'SKIPPED' });
    return attempts;
  }
}
