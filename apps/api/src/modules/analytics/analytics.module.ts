import { Global, Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { AnalyticsService } from './analytics.service';
import { AnalyticsController } from './analytics.controller';
import { AnalyticsRetentionCron } from './analytics-retention.cron';
import { AnalyticsOpsController } from './analytics-ops.controller';

/**
 * Global so every feature module can inject `AnalyticsService` without
 * importing AnalyticsModule explicitly. Event capture is pervasive; we
 * keep the wiring frictionless rather than adding boilerplate to every
 * feature module.
 */
@Global()
@Module({
  imports: [PrismaModule],
  controllers: [AnalyticsController, AnalyticsOpsController],
  providers: [AnalyticsService, AnalyticsRetentionCron],
  exports: [AnalyticsService, AnalyticsRetentionCron],
})
export class AnalyticsModule {}
