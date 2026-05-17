import {
  Controller,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { MediaService } from './media.service';

@Controller()
export class MediaController {
  constructor(private readonly svc: MediaService) {}

  @Post('media/upload')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 6 * 1024 * 1024 }, // hard cap slightly above 5MB; service validates exact
    }),
  )
  upload(
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: RequestUser,
  ) {
    return this.svc.uploadImage(file, user.id);
  }
}
