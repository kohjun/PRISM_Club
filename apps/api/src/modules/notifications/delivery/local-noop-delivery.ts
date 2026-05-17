import { Injectable, Logger } from '@nestjs/common';
import {
  DeliveryAttempt,
  DeliveryRequest,
  INotificationDeliverer,
} from './notification-delivery.interface';

/**
 * Default deliverer: writes a debug log line and returns SKIPPED for
 * EMAIL + PUSH. Used in dev / test / smoke. The in-app row is already
 * persisted by NotificationService before this is called.
 */
@Injectable()
export class LocalNoopDelivery implements INotificationDeliverer {
  private readonly log = new Logger(LocalNoopDelivery.name);

  mode(): string {
    return 'noop';
  }

  async deliver(req: DeliveryRequest): Promise<DeliveryAttempt[]> {
    this.log.debug(
      `notification[${req.type}] queued in-app for user=${req.userId} (email/push: noop)`,
    );
    return [
      { channel: 'IN_APP', status: 'SENT', ref: req.notificationId },
      { channel: 'EMAIL', status: 'SKIPPED' },
      { channel: 'PUSH', status: 'SKIPPED' },
    ];
  }
}
