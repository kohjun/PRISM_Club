import { Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { AccessControlModule } from '../../shared/access-control.module';
import { SignalService } from './signal.service';
import { SignalController } from './signal.controller';

@Module({
  imports: [PrismaModule, AccessControlModule],
  controllers: [SignalController],
  providers: [SignalService],
})
export class SignalsModule {}
