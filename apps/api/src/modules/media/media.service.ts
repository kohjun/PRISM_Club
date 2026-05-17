import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as crypto from 'crypto';
import { PrismaService } from '../../shared/prisma.service';
import {
  IMediaStorage,
  MEDIA_STORAGE,
} from './storage/media-storage.interface';

const MAX_SIZE_BYTES = 5 * 1024 * 1024; // 5MB
const ALLOWED_MIME = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
]);
const MIME_TO_EXT: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
};

export interface MediaAssetDTO {
  id: string;
  kind: 'IMAGE';
  filename: string;
  mime_type: string;
  size_bytes: number;
  url: string;
  created_at: string;
}

@Injectable()
export class MediaService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(MEDIA_STORAGE) private readonly storage: IMediaStorage,
  ) {}

  storageMode(): string {
    return this.storage.mode();
  }

  async uploadImage(
    file: Express.Multer.File | undefined,
    ownerId: string,
  ): Promise<MediaAssetDTO> {
    if (!file) {
      throw new BadRequestException(
        'file is required (multipart field: file)',
      );
    }
    if (!ALLOWED_MIME.has(file.mimetype)) {
      throw new BadRequestException(
        `Unsupported MIME type: ${file.mimetype}. Allowed: jpg/png/webp/gif`,
      );
    }
    if (file.size > MAX_SIZE_BYTES) {
      throw new BadRequestException(
        `File too large: ${file.size} bytes (max ${MAX_SIZE_BYTES})`,
      );
    }

    const id = crypto.randomUUID();
    const ext = MIME_TO_EXT[file.mimetype];

    const stored = await this.storage.upload({
      id,
      ext,
      contentType: file.mimetype,
      body: file.buffer,
    });

    const row = await this.prisma.mediaAsset.create({
      data: {
        id,
        ownerId,
        kind: 'IMAGE',
        filename: file.originalname || `${id}.${ext}`,
        mimeType: file.mimetype,
        sizeBytes: file.size,
        path: stored.urlPath,
      },
    });

    return this.toDTO(row);
  }

  async getById(id: string): Promise<MediaAssetDTO> {
    const row = await this.prisma.mediaAsset.findUnique({ where: { id } });
    if (!row) throw new NotFoundException(`Media not found: ${id}`);
    return this.toDTO(row);
  }

  private toDTO(row: {
    id: string;
    kind: string;
    filename: string;
    mimeType: string;
    sizeBytes: number;
    path: string;
    createdAt: Date;
  }): MediaAssetDTO {
    return {
      id: row.id,
      kind: row.kind as 'IMAGE',
      filename: row.filename,
      mime_type: row.mimeType,
      size_bytes: row.sizeBytes,
      url: row.path,
      created_at: row.createdAt.toISOString(),
    };
  }
}
