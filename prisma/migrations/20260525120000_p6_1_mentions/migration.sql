-- P6.1 mentions: per-mention row so the "내가 멘션된 곳" feed and
-- per-post mention cleanup are O(index lookup), not a body re-parse.

-- CreateTable
CREATE TABLE "mentions" (
    "id" UUID NOT NULL,
    "source_type" TEXT NOT NULL,
    "source_id" UUID NOT NULL,
    "mentioned_user_id" UUID NOT NULL,
    "actor_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "mentions_pkey" PRIMARY KEY ("id")
);

-- A user is mentioned at most once per (source_type, source_id) row.
-- Re-saving the same body with the same @nickname is a no-op upsert.
CREATE UNIQUE INDEX "mentions_source_user_unique"
    ON "mentions"("source_type", "source_id", "mentioned_user_id");

-- "내 멘션 함" feed: recipient + recency.
CREATE INDEX "mentions_mentioned_user_idx"
    ON "mentions"("mentioned_user_id", "created_at" DESC);

-- Cleanup on post/reply delete: O(index) lookup by source.
CREATE INDEX "mentions_source_idx"
    ON "mentions"("source_type", "source_id");

-- FK to users for both columns. Cascade on user deletion so we don't
-- leak orphan mention rows when an account is hard-deleted.
ALTER TABLE "mentions"
    ADD CONSTRAINT "mentions_mentioned_user_id_fkey"
    FOREIGN KEY ("mentioned_user_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "mentions"
    ADD CONSTRAINT "mentions_actor_id_fkey"
    FOREIGN KEY ("actor_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
