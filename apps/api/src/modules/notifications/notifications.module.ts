import { Logger, Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { AccessControlModule } from '../../shared/access-control.module';
import { NotificationService } from './notification.service';
import { NotificationPreferencesService } from './notification-preferences.service';
import { DeviceTokenService } from './device-token.service';
import { NotificationController } from './notification.controller';
import { LocalNoopDelivery } from './delivery/local-noop-delivery';
import { EmailDelivery } from './delivery/email-delivery';
import { PushDelivery } from './delivery/push-delivery';
import { NOTIFICATION_DELIVERY } from './delivery/notification-delivery.interface';

const moduleLog = new Logger('NotificationsModule');

function selectDelivery():
  | typeof LocalNoopDelivery
  | typeof EmailDelivery
  | typeof PushDelivery {
  const mode = (process.env.NOTIFICATION_DELIVERY_MODE ?? 'noop').toLowerCase();
  if (mode === 'email') {
    moduleLog.log('Notification delivery mode: email');
    return EmailDelivery;
  }
  if (mode === 'push') {
    moduleLog.log('Notification delivery mode: push');
    return PushDelivery;
  }
  return LocalNoopDelivery;
}

@Module({
  imports: [PrismaModule, AccessControlModule],
  controllers: [NotificationController],
  providers: [
    NotificationService,
    NotificationPreferencesService,
    DeviceTokenService,
    LocalNoopDelivery,
    EmailDelivery,
    PushDelivery,
    { provide: NOTIFICATION_DELIVERY, useClass: selectDelivery() },
  ],
  exports: [
    NotificationService,
    NotificationPreferencesService,
    DeviceTokenService,
  ],
})
export class NotificationsModule {}
