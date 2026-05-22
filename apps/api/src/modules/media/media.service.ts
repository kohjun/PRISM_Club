import {
  BadRequestException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import * as crypto from 'crypto';
import sharp from 'sharp';
import { PrismaService } from '../../shared/prisma.service';
import { AnalyticsService } from '../analytics/analytics.service';
import { MetricsService } from '../../shared/metrics.service';
import {
  IMediaStorage,
  MEDIA_STORAGE,
  MediaUploadResult,
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

// Variant rendition widths. We always emit webp because it's universally
// supported by modern mobile clients and ~30% smaller than equivalent jpeg.
const VARIANT_WIDTHS = { thumb: 480, md: 1080 } as const;
type VariantKey = keyof typeof VARIANT_WIDTHS;

export interface MediaAssetDTO {
  id: string;
  kind: 'IMAGE';
  filename: string;
  mime_type: string;
  size_bytes: number;
  url: string;
  cdn_url: string | null;
  variants: Record<string, string>;
  width: number | null;
  height: number | null;
  created_at: string;
}

@Injectable()
export class MediaService {
  private readonly log = new Logger(MediaService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(MEDIA_STORAGE) private readonly storage: IMediaStorage,
    private readonly analytics: AnalyticsService,
    private readonly metrics: MetricsService,
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

    // 1. Upload the original byte-for-byte.
    let stored;
    try {
      stored = await this.storage.upload({
        id,
        ext,
        contentType: file.mimetype,
        body: file.buffer,
      });
    } catch (e) {
      this.metrics.inc('media.upload.fail');
      throw e;
    }
    this.metrics.inc('media.upload.success');
    this.metrics.record('media.upload.bytes', file.size);

    // 2. Read dimensions + render variants. Failures here are non-fatal —
    //    we still persist the original so the asset is usable; variants can
    //    be reprocessed by a background script later.
    const meta = await this.readImageMeta(file.buffer);
    const variants = await this.renderVariants(id, file.buffer, file.mimetype);

    const row = await this.prisma.mediaAsset.create({
      data: {
        id,
        ownerId,
        kind: 'IMAGE',
        filename: file.originalname || `${id}.${ext}`,
        mimeType: file.mimetype,
        sizeBytes: file.size,
        path: stored.urlPath,
        cdnUrl: stored.urlPath, // canonical client-facing URL (may equal path
                                 // in local mode; becomes the CDN URL when S3
                                 // / R2 is configured with MEDIA_PUBLIC_BASE_URL)
        variants: variants as object,
        width: meta?.width ?? null,
        height: meta?.height ?? null,
        storageKey: `${id}.${ext}`,
      },
    });

    this.analytics.record({
      actorId: ownerId,
      eventType: 'MEDIA_UPLOADED',
      payload: {
        media_id: row.id,
        mime_type: file.mimetype,
        size_bytes: file.size,
        storage_mode: this.storage.mode(),
        variant_count: Object.keys(variants).length,
      },
    });

    return this.toDTO(row);
  }

  async getById(id: string): Promise<MediaAssetDTO> {
    const row = await this.prisma.mediaAsset.findUnique({ where: { id } });
    if (!row) throw new NotFoundException(`Media not found: ${id}`);
    return this.toDTO(row);
  }

  private async readImageMeta(
    body: Buffer,
  ): Promise<{ width: number; height: number } | null> {
    try {
      const meta = await sharp(body).metadata();
      if (!meta.width || !meta.height) return null;
      return { width: meta.width, height: meta.height };
    } catch (e) {
      this.log.warn(
        `media meta read failed: ${e instanceof Error ? e.message : String(e)}`,
      );
      return null;
    }
  }

  /**
   * Render webp variants and upload them alongside the original.
   *
   * Animated GIFs are skipped (sharp's resize loses animation by default
   * and the typical upload is small enough not to need a thumbnail).
   */
  private async renderVariants(
    id: string,
    body: Buffer,
    mime: string,
  ): Promise<Record<string, string>> {
    if (mime === 'image/gif') {
      return {};
    }
    const out: Record<string, string> = {};
    for (const [name, width] of Object.entries(VARIANT_WIDTHS) as Array<
      [VariantKey, number]
    >) {
      try {
        const buf = await sharp(body)
          .resize({ width, withoutEnlargement: true })
          .webp({ quality: 82 })
          .toBuffer();
        const result: MediaUploadResult = await this.storage.upload({
          id: `${id}-${name}`,
          ext: 'webp',
          contentType: 'image/webp',
          body: buf,
        });
        out[name] = result.urlPath;
      } catch (e) {
        this.log.warn(
          `variant[${name}] render/upload failed for ${id}: ${e instanceof Error ? e.message : String(e)}`,
        );
        // Continue with the other variants; partial success is acceptable.
      }
    }
    return out;
  }

  private toDTO(row: {
    id: string;
    kind: string;
    filename: string;
    mimeType: string;
    sizeBytes: number;
    path: string;
    cdnUrl: string | null;
    variants: unknown;
    width: number | null;
    height: number | null;
    createdAt: Date;
  }): MediaAssetDTO {
    return {
      id: row.id,
      kind: row.kind as 'IMAGE',
      filename: row.filename,
      mime_type: row.mimeType,
      size_bytes: row.sizeBytes,
      url: row.path,
      cdn_url: row.cdnUrl,
      variants: (row.variants as Record<string, string>) ?? {},
      width: row.width,
      height: row.height,
      created_at: row.createdAt.toISOString(),
    };
  }
}
