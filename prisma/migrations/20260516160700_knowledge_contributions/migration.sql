-- CreateTable
CREATE TABLE "knowledge_contributions" (
    "id" UUID NOT NULL,
    "topic_hub_id" UUID NOT NULL,
    "contributor_id" UUID NOT NULL,
    "target_block_id" UUID,
    "proposed_block_type" TEXT NOT NULL,
    "proposed_title" TEXT NOT NULL,
    "proposed_body" TEXT NOT NULL,
    "evidence_type" TEXT,
    "evidence_target_id" UUID,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "curator_note" TEXT,
    "resolved_by" UUID,
    "resolved_at" TIMESTAMPTZ(6),
    "snapshot_block_type" TEXT,
    "snapshot_title" TEXT,
    "snapshot_body" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "knowledge_contributions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "knowledge_contributions_topic_hub_id_status_created_at_idx" ON "knowledge_contributions"("topic_hub_id", "status", "created_at" DESC);

-- CreateIndex
CREATE INDEX "knowledge_contributions_contributor_id_created_at_idx" ON "knowledge_contributions"("contributor_id", "created_at" DESC);

-- AddForeignKey
ALTER TABLE "knowledge_contributions" ADD CONSTRAINT "knowledge_contributions_topic_hub_id_fkey" FOREIGN KEY ("topic_hub_id") REFERENCES "topic_hubs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "knowledge_contributions" ADD CONSTRAINT "knowledge_contributions_contributor_id_fkey" FOREIGN KEY ("contributor_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "knowledge_contributions" ADD CONSTRAINT "knowledge_contributions_resolved_by_fkey" FOREIGN KEY ("resolved_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "knowledge_contributions" ADD CONSTRAINT "knowledge_contributions_target_block_id_fkey" FOREIGN KEY ("target_block_id") REFERENCES "knowledge_blocks"("id") ON DELETE SET NULL ON UPDATE CASCADE;
