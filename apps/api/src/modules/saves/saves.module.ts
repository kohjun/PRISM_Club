import { Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { AccessControlModule } from '../../shared/access-control.module';
import { SaveService } from './save.service';
import { SaveController } from './save.controller';

@Module({
  imports: [PrismaModule, AccessControlModule],
  controllers: [SaveController],
  providers: [SaveService],
  exports: [SaveService],
})
export class SavesModule {}
