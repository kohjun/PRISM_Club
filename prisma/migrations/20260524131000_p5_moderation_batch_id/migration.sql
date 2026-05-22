-- P5.3 moderation bulk-resolve batch identifier.

ALTER TABLE "moderation_actions"
    ADD COLUMN "batch_id" UUID;

CREATE INDEX "moderation_actions_batch_id_idx"
    ON "moderation_actions"("batch_id");
