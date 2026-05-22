-- P6.3 notification grouping.
--
-- Adds `group_key` (composite of type + target) so a fresh write can
-- look for an existing un-read row inside a 1h window and append the
-- actor instead of creating a duplicate notification. `updated_at`
-- bumps when an actor is appended so the recipient sees the row pop
-- back to the top of the inbox.

ALTER TABLE "notifications"
    ADD COLUMN "group_key" TEXT,
    ADD COLUMN "updated_at" TIMESTAMPTZ(6);

-- Backfill: all existing rows are their own "group of one" — keep
-- group_key null so they don't unexpectedly absorb a new write.
-- `updated_at` defaults to `created_at` so the read DTO doesn't have
-- a null-handling branch.
UPDATE "notifications" SET "updated_at" = "created_at";

ALTER TABLE "notifications"
    ALTER COLUMN "updated_at" SET NOT NULL,
    ALTER COLUMN "updated_at" SET DEFAULT CURRENT_TIMESTAMP;

-- Upsert lookup: latest un-read row per (recipient, group_key) within
-- the 1h merge window.
CREATE INDEX "notifications_group_key_idx"
    ON "notifications"("user_id", "group_key", "created_at" DESC);
