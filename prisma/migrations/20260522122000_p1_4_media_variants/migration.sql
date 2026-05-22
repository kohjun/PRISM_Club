-- P1.4 Media variants: server-side thumbnail + medium webp renditions.
-- All columns are additive; consumers prefer `cdn_url` when set but fall
-- back to the legacy `path` URL.

-- AlterTable
ALTER TABLE "media_assets"
    ADD COLUMN "cdn_url" TEXT,
    ADD COLUMN "variants" JSONB NOT NULL DEFAULT '{}',
    ADD COLUMN "width" INTEGER,
    ADD COLUMN "height" INTEGER,
    ADD COLUMN "storage_key" TEXT;
