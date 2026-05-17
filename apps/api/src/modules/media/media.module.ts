import { Logger, Module } from '@nestjs/common';
import { PrismaModule } from '../../shared/prisma.module';
import { MediaService } from './media.service';
import { MediaController } from './media.controller';
import { LocalMediaStorage } from './storage/local-media-storage';
import { S3MediaStorage } from './storage/s3-media-storage';
import { MEDIA_STORAGE } from './storage/media-storage.interface';

const moduleLog = new Logger('MediaModule');

function selectStorageClass():
  | typeof LocalMediaStorage
  | typeof S3MediaStorage {
  const mode = (process.env.MEDIA_STORAGE_MODE ?? 'local').toLowerCase();
  if (mode === 's3') {
    moduleLog.log('Media storage mode: s3');
    return S3MediaStorage;
  }
  return LocalMediaStorage;
}

@Module({
  imports: [PrismaModule],
  controllers: [MediaController],
  providers: [
    MediaService,
    LocalMediaStorage,
    S3MediaStorage,
    { provide: MEDIA_STORAGE, useClass: selectStorageClass() },
  ],
  exports: [MediaService],
})
export class MediaModule {}
