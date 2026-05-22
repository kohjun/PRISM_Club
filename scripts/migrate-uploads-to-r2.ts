/**
 * P1.4 backfill — copy every legacy `apps/api/uploads/<id>.<ext>` file
 * (and its rendered variants) into the configured S3/R2 bucket and
 * update the `media_assets` row so the canonical `cdn_url` points at
 * the CDN host.
 *
 * Idempotent: rows where `cdn_url` already starts with
 * `MEDIA_PUBLIC_BASE_URL` are skipped. Rerunning the script is safe.
 *
 * Required env (all from STAGING_SETUP §3 / DEPLOYMENT.md):
 *   S3_BUCKET                 R2 bucket name
 *   S3_ENDPOINT               e.g. https://<account>.r2.cloudflarestorage.com
 *   S3_ACCESS_KEY_ID
 *   S3_SECRET_ACCESS_KEY
 *   MEDIA_PUBLIC_BASE_URL     e.g. https://cdn.prism.club (no trailing slash)
 *   S3_REGION                 (optional, default 'auto')
 *   S3_OBJECT_PREFIX          (optional, default 'uploads')
 *   S3_FORCE_PATH_STYLE       (optional, default '1' — needed for R2)
 *
 * Usage:
 *   DATABASE_URL=... S3_BUCKET=... ... \
 *     node --import tsx scripts/migrate-uploads-to-r2.ts [--dry-run]
 */
import { PrismaClient } from '@prisma/client';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import * as fs from 'fs';
import * as path from 'path';

const dryRun = process.argv.includes('--dry-run');
const prisma = new PrismaClient();

function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v || v.trim().length === 0) {
    console.error(`Missing required env: ${name}`);
    process.exit(2);
  }
  return v;
}

const BUCKET = requireEnv('S3_BUCKET');
const ENDPOINT = requireEnv('S3_ENDPOINT');
const ACCESS_KEY = requireEnv('S3_ACCESS_KEY_ID');
const SECRET_KEY = requireEnv('S3_SECRET_ACCESS_KEY');
const PUBLIC_BASE = requireEnv('MEDIA_PUBLIC_BASE_URL').replace(/\/+$/, '');
const REGION = process.env.S3_REGION ?? 'auto';
const PREFIX = (process.env.S3_OBJECT_PREFIX ?? 'uploads').replace(
  /(^\/+|\/+$)/g,
  '',
);
const FORCE_PATH_STYLE = (process.env.S3_FORCE_PATH_STYLE ?? '1') === '1';

const UPLOADS_DIR = path.resolve(
  process.cwd(),
  'apps',
  'api',
  'uploads',
);

const client = dryRun
  ? null
  : new S3Client({
      endpoint: ENDPOINT,
      region: REGION,
      forcePathStyle: FORCE_PATH_STYLE,
      credentials: {
        accessKeyId: ACCESS_KEY,
        secretAccessKey: SECRET_KEY,
      },
    });

function guessExt(filename: string, mime: string): string {
  const dot = filename.lastIndexOf('.');
  if (dot > 0 && dot < filename.length - 1) return filename.slice(dot + 1);
  switch (mime) {
    case 'image/jpeg':
      return 'jpg';
    case 'image/png':
      return 'png';
    case 'image/webp':
      return 'webp';
    case 'image/gif':
      return 'gif';
    default:
      return 'bin';
  }
}

function publicUrl(key: string): string {
  return `${PUBLIC_BASE}/${key}`;
}

async function uploadFile(
  localPath: string,
  objectKey: string,
  mime: string,
): Promise<boolean> {
  if (!fs.existsSync(localPath)) return false;
  const body = await fs.promises.readFile(localPath);
  if (dryRun) return true;
  await client!.send(
    new PutObjectCommand({
      Bucket: BUCKET,
      Key: objectKey,
      Body: body,
      ContentType: mime,
      CacheControl: 'public, max-age=31536000, immutable',
    }),
  );
  return true;
}

async function main() {
  console.log(
    `[migrate-uploads-to-r2] bucket=${BUCKET} endpoint=${ENDPOINT} public_base=${PUBLIC_BASE} dry_run=${dryRun}`,
  );
  if (!fs.existsSync(UPLOADS_DIR)) {
    console.log(`  uploads dir missing (${UPLOADS_DIR}) — nothing to migrate`);
    return;
  }

  const rows = await prisma.mediaAsset.findMany({
    select: {
      id: true,
      filename: true,
      mimeType: true,
      path: true,
      cdnUrl: true,
      storageKey: true,
      variants: true,
    },
  });

  let scanned = 0;
  let migrated = 0;
  let alreadyDone = 0;
  let missingLocal = 0;
  let variantHits = 0;

  for (const row of rows) {
    scanned += 1;
    if (row.cdnUrl && row.cdnUrl.startsWith(PUBLIC_BASE)) {
      alreadyDone += 1;
      continue;
    }
    const ext = guessExt(row.filename, row.mimeType);
    const objectKey = `${PREFIX}/${row.id}.${ext}`;
    const local = path.join(UPLOADS_DIR, `${row.id}.${ext}`);
    const ok = await uploadFile(local, objectKey, row.mimeType);
    if (!ok) {
      missingLocal += 1;
      console.warn(
        `  WARN media_assets.id=${row.id} local missing (${local}) — skipping`,
      );
      continue;
    }

    const variantsObj =
      typeof row.variants === 'object' && row.variants !== null
        ? (row.variants as Record<string, string>)
        : {};
    const newVariants: Record<string, string> = {};
    for (const [name] of Object.entries(variantsObj)) {
      const variantKey = `${PREFIX}/${row.id}-${name}.webp`;
      const variantLocal = path.join(UPLOADS_DIR, `${row.id}-${name}.webp`);
      const variantOk = await uploadFile(
        variantLocal,
        variantKey,
        'image/webp',
      );
      if (variantOk) {
        newVariants[name] = publicUrl(variantKey);
        variantHits += 1;
      }
    }

    if (!dryRun) {
      await prisma.mediaAsset.update({
        where: { id: row.id },
        data: {
          cdnUrl: publicUrl(objectKey),
          storageKey: objectKey,
          variants: Object.keys(newVariants).length > 0 ? newVariants : row.variants,
        },
      });
    }
    migrated += 1;
  }

  console.log(
    `[migrate-uploads-to-r2] scanned=${scanned} migrated=${migrated} already_done=${alreadyDone} missing_local=${missingLocal} variants=${variantHits} dry_run=${dryRun}`,
  );
}

main()
  .catch((e) => {
    console.error('migrate-uploads-to-r2 failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
