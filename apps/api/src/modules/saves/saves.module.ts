import { Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { AccessControlModule } from '../../shared/access-control.module';
import { SaveService } from './save.service';
import { SaveController } from './save.controller';
import { SaveCollectionService } from './save-collection.service';
import { SaveCollectionController } from './save-collection.controller';

@Module({
  imports: [PrismaModule, AccessControlModule],
  controllers: [SaveController, SaveCollectionController],
  providers: [SaveService, SaveCollectionService],
  exports: [SaveService, SaveCollectionService],
})
export class SavesModule {}
