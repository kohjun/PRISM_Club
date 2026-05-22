-- P2.1 Knowledge Block Revision History.
-- Adds the audit-trail table that the contribution flow now writes to on
-- every APPROVE, plus a one-shot backfill that seeds version=1 SEED rows
-- for blocks that pre-date this migration.

-- CreateTable
CREATE TABLE "knowledge_block_revisions" (
    "id" UUID NOT NULL,
    "block_id" UUID NOT NULL,
    "version" INTEGER NOT NULL,
    "block_type" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "changed_by_id" UUID,
    "changed_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "contribution_id" UUID,
    "source" TEXT NOT NULL,

    CONSTRAINT "knowledge_block_revisions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "knowledge_block_revisions_block_id_version_key"
    ON "knowledge_block_revisions"("block_id", "version");

-- CreateIndex
CREATE INDEX "knowledge_block_revisions_block_id_changed_at_idx"
    ON "knowledge_block_revisions"("block_id", "changed_at" DESC);

-- CreateIndex
CREATE INDEX "knowledge_block_revisions_changed_by_id_changed_at_idx"
    ON "knowledge_block_revisions"("changed_by_id", "changed_at" DESC);

-- AddForeignKey
ALTER TABLE "knowledge_block_revisions"
    ADD CONSTRAINT "knowledge_block_revisions_block_id_fkey"
    FOREIGN KEY ("block_id") REFERENCES "knowledge_blocks"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "knowledge_block_revisions"
    ADD CONSTRAINT "knowledge_block_revisions_changed_by_id_fkey"
    FOREIGN KEY ("changed_by_id") REFERENCES "users"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "knowledge_block_revisions"
    ADD CONSTRAINT "knowledge_block_revisions_contribution_id_fkey"
    FOREIGN KEY ("contribution_id") REFERENCES "knowledge_contributions"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;

-- Backfill: every existing block gets a version=1 SEED revision so the
-- timeline isn't empty for pre-existing data. `changed_by_id` stays NULL
-- because the seed/baseline content has no original author row attached.
INSERT INTO "knowledge_block_revisions" (
    "id", "block_id", "version", "block_type", "title", "body",
    "changed_by_id", "changed_at", "contribution_id", "source"
)
SELECT
    gen_random_uuid(),
    "id",
    1,
    "block_type",
    "title",
    "body",
    NULL,
    COALESCE("updated_at", CURRENT_TIMESTAMP),
    NULL,
    'SEED'
FROM "knowledge_blocks";
