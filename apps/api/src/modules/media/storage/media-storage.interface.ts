/**
 * MediaStorage abstraction (M16).
 *
 * Local dev defaults to `LocalMediaStorage` (writes to UPLOADS_DIR and
 * exposes /uploads/* via Nest's useStaticAssets).
 *
 * Production can switch to `S3MediaStorage` by setting MEDIA_STORAGE_MODE=s3
 * and the S3_* env vars. The returned `urlPath` is what gets persisted on
 * `MediaAsset.path` and returned to clients — keep it stable across modes.
 */

export interface MediaUploadInput {
  /** Generated UUID for this asset (also the storage object key prefix). */
  id: string;
  /** File extension without leading dot. */
  ext: string;
  /** MIME content type. */
  contentType: string;
  /** Raw bytes. */
  body: Buffer;
}

export interface MediaUploadResult {
  /** URL or relative path that clients use to fetch the asset. */
  urlPath: string;
}

export interface IMediaStorage {
  /** Persist bytes; return the URL/path clients should use. */
  upload(input: MediaUploadInput): Promise<MediaUploadResult>;
  /** Human-readable mode label for logs / diagnostics. */
  mode(): string;
}

export const MEDIA_STORAGE = Symbol('IMediaStorage');
