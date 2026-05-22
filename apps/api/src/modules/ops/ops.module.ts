import { Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { OpsService } from './ops.service';
import { OpsController } from './ops.controller';
import { AuditLogService } from './audit-log.service';
import { AuditLogController } from './audit-log.controller';

@Module({
  imports: [PrismaModule],
  controllers: [OpsController, AuditLogController],
  providers: [OpsService, AuditLogService],
  exports: [AuditLogService],
})
export class OpsModule {}
