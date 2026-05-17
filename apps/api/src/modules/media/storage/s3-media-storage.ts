import {
  Injectable,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import {
  IMediaStorage,
  MediaUploadInput,
  MediaUploadResult,
} from './media-storage.interface';

/**
 * S3-compatible storage (AWS S3, Cloudflare R2, MinIO, etc.).
 *
 * Activated by `MEDIA_STORAGE_MODE=s3`. Required env vars:
 *
 *   S3_BUCKET                 (required)
 *   S3_REGION                 (required; "us-east-1" for AWS, "auto" for R2)
 *   S3_ACCESS_KEY_ID          (required)
 *   S3_SECRET_ACCESS_KEY      (required)
 *   S3_ENDPOINT               (optional — for non-AWS S3-compatible hosts)
 *   S3_FORCE_PATH_STYLE       (optional, "1" / "true")
 *   S3_OBJECT_PREFIX          (optional, defaults to "uploads")
 *   MEDIA_PUBLIC_BASE_URL     (required — public URL prefix that clients can fetch)
 *
 * Configuration is validated lazily on the first upload so registering
 * this provider when MEDIA_STORAGE_MODE=local never crashes API boot.
 */
@Injectable()
export class S3MediaStorage implements IMediaStorage {
  private readonly log = new Logger(S3MediaStorage.name);
  private _client: S3Client | null = null;
  private _bucket = '';
  private _publicBaseUrl = '';
  private _objectPrefix = 'uploads';

  private ensureConfigured(): void {
    if (this._client !== null) return;

    const bucket = process.env.S3_BUCKET;
    const region = process.env.S3_REGION;
    const accessKeyId = process.env.S3_ACCESS_KEY_ID;
    const secretAccessKey = process.env.S3_SECRET_ACCESS_KEY;
    const publicBaseUrl = process.env.MEDIA_PUBLIC_BASE_URL;
    const endpoint = process.env.S3_ENDPOINT;
    const forcePathStyle =
      process.env.S3_FORCE_PATH_STYLE === '1' ||
      process.env.S3_FORCE_PATH_STYLE === 'true';

    const missing: string[] = [];
    if (!bucket) missing.push('S3_BUCKET');
    if (!region) missing.push('S3_REGION');
    if (!accessKeyId) missing.push('S3_ACCESS_KEY_ID');
    if (!secretAccessKey) missing.push('S3_SECRET_ACCESS_KEY');
    if (!publicBaseUrl) missing.push('MEDIA_PUBLIC_BASE_URL');
    if (missing.length > 0) {
      throw new InternalServerErrorException(
        `S3MediaStorage misconfigured — missing env: ${missing.join(', ')}`,
      );
    }

    this._bucket = bucket!;
    this._publicBaseUrl = publicBaseUrl!.replace(/\/+$/, '');
    this._objectPrefix = (process.env.S3_OBJECT_PREFIX ?? 'uploads').replace(
      /^\/+|\/+$/g,
      '',
    );

    this._client = new S3Client({
      region: region!,
      credentials: {
        accessKeyId: accessKeyId!,
        secretAccessKey: secretAccessKey!,
      },
      endpoint,
      forcePathStyle,
    });
  }

  mode(): string {
    // Avoid throwing here — diagnostics should work even before first upload.
    return process.env.S3_BUCKET
      ? `s3(bucket=${process.env.S3_BUCKET})`
      : 's3(misconfigured)';
  }

  async upload(input: MediaUploadInput): Promise<MediaUploadResult> {
    this.ensureConfigured();
    const objectKey = `${this._objectPrefix}/${input.id}.${input.ext}`;
    try {
      await this._client!.send(
        new PutObjectCommand({
          Bucket: this._bucket,
          Key: objectKey,
          Body: input.body,
          ContentType: input.contentType,
        }),
      );
    } catch (e) {
      this.log.error(
        `S3 putObject failed for ${objectKey}: ${e instanceof Error ? e.message : String(e)}`,
      );
      throw new InternalServerErrorException(
        'Failed to upload media to object storage',
      );
    }
    return { urlPath: `${this._publicBaseUrl}/${objectKey}` };
  }
}
