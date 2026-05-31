import { Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { AccessControlModule } from '../../shared/access-control.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { DmService } from './dm.service';
import { DmLifecycleCron } from './dm-lifecycle.cron';
import { DmController } from './dm.controller';

/**
 * P6.9 — Scoped DM. RateLimitService / BlockMuteService / AnalyticsService
 * are global; NotificationsModule is imported for the recipient
 * notification, and AccessControlModule for the space-policy gate.
 */
@Module({
  imports: [PrismaModule, AccessControlModule, NotificationsModule],
  providers: [DmService, DmLifecycleCron],
  controllers: [DmController],
  exports: [DmService],
})
export class DmModule {}
