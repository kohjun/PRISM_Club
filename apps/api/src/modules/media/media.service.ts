import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

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
  // Resolve uploads dir relative to the API working directory.
  // In dev (npm run dev) cwd is apps/api so this matches the static-served path.
  private readonly uploadsDir = path.join(process.cwd(), 'uploads');

  constructor(private readonly prisma: PrismaService) {
    if (!fs.existsSync(this.uploadsDir)) {
      fs.mkdirSync(this.uploadsDir, { recursive: true });
    }
  }

  async uploadImage(
    file: Express.Multer.File | undefined,
    ownerId: string,
  ): Promise<MediaAssetDTO> {
    if (!file) {
      throw new BadRequestException('file is required (multipart field: file)');
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
    const storedName = `${id}.${ext}`;
    const filePath = path.join(this.uploadsDir, storedName);
    fs.writeFileSync(filePath, file.buffer);

    const relPath = `/uploads/${storedName}`;
    const row = await this.prisma.mediaAsset.create({
      data: {
        id,
        ownerId,
        kind: 'IMAGE',
        filename: file.originalname || storedName,
        mimeType: file.mimetype,
        sizeBytes: file.size,
        path: relPath,
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
