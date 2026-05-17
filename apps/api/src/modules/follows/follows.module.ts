import { Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { AccessControlModule } from '../../shared/access-control.module';
import { FollowService } from './follow.service';
import { FollowController } from './follow.controller';

@Module({
  imports: [PrismaModule, AccessControlModule],
  controllers: [FollowController],
  providers: [FollowService],
  exports: [FollowService],
})
export class FollowsModule {}
