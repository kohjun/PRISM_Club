import { Global, Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { AccessControlModule } from '../../shared/access-control.module';
import { ReportService } from './report.service';
import { ReportController } from './report.controller';
import { AutoModerationService } from './auto-moderation.service';

/**
 * Global so PostService / ReportService can inject AutoModerationService
 * from the create paths without an explicit ModerationModule import each
 * time (mirrors the AnalyticsModule pattern).
 */
@Global()
@Module({
  imports: [PrismaModule, AccessControlModule],
  controllers: [ReportController],
  providers: [ReportService, AutoModerationService],
  exports: [ReportService, AutoModerationService],
})
export class ModerationModule {}
