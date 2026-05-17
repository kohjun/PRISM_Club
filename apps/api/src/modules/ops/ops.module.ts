import { Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { OpsService } from './ops.service';
import { OpsController } from './ops.controller';

@Module({
  imports: [PrismaModule],
  controllers: [OpsController],
  providers: [OpsService],
})
export class OpsModule {}
