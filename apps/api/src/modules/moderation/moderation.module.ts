import { Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { AccessControlModule } from '../../shared/access-control.module';
import { ReportService } from './report.service';
import { ReportController } from './report.controller';

@Module({
  imports: [PrismaModule, AccessControlModule],
  controllers: [ReportController],
  providers: [ReportService],
  exports: [ReportService],
})
export class ModerationModule {}
