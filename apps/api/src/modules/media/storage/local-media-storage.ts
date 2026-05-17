import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import {
  IMediaStorage,
  MediaUploadInput,
  MediaUploadResult,
} from './media-storage.interface';

/**
 * Local-filesystem media storage. Default for dev/test.
 *
 * Writes to UPLOADS_DIR (resolved against process cwd if relative) and
 * returns `/uploads/<id>.<ext>` URLs. The same path is served by
 * `app.useStaticAssets` in `main.ts`.
 */
@Injectable()
export class LocalMediaStorage implements IMediaStorage {
  private readonly log = new Logger(LocalMediaStorage.name);
  private readonly uploadsDir = (() => {
    const env = process.env.UPLOADS_DIR;
    if (!env || env.trim() === '') {
      return path.join(process.cwd(), 'uploads');
    }
    return path.isAbsolute(env) ? env : path.join(process.cwd(), env);
  })();

  constructor() {
    if (!fs.existsSync(this.uploadsDir)) {
      fs.mkdirSync(this.uploadsDir, { recursive: true });
    }
  }

  mode(): string {
    return `local(${this.uploadsDir})`;
  }

  async upload(input: MediaUploadInput): Promise<MediaUploadResult> {
    const storedName = `${input.id}.${input.ext}`;
    const filePath = path.join(this.uploadsDir, storedName);
    try {
      await fs.promises.writeFile(filePath, input.body);
    } catch (e) {
      this.log.error(
        `LocalMediaStorage write failed: ${e instanceof Error ? e.message : String(e)}`,
      );
      throw new InternalServerErrorException('Failed to persist media file');
    }
    return { urlPath: `/uploads/${storedName}` };
  }
}
