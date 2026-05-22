-- P4 Social growth — bundled migration for P4.2/P4.3/P4.4/P4.6.
--   - saved_items.collection_id + saved_collections (P4.4 folders)
--   - post_quotes                                    (P4.2 quote-share)
--   - follow_recommendations                         (P4.3 candidate cache)
--   - notification_preferences.weekly_digest_*        (P4.6 opt-in)

-- ============================================================
-- P4.4 Saved collections
-- ============================================================
CREATE TABLE "saved_collections" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "name" VARCHAR(50) NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "saved_collections_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "saved_collections_user_id_name_key"
    ON "saved_collections"("user_id", "name");

ALTER TABLE "saved_collections"
    ADD CONSTRAINT "saved_collections_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "saved_items"
    ADD COLUMN "collection_id" UUID;

ALTER TABLE "saved_items"
    ADD CONSTRAINT "saved_items_collection_id_fkey"
    FOREIGN KEY ("collection_id") REFERENCES "saved_collections"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;

-- Replace the old (user_id, created_at) index with the wider one that
-- also covers folder filters.
DROP INDEX IF EXISTS "saved_items_user_id_created_at_idx";
CREATE INDEX "saved_items_user_id_collection_id_created_at_idx"
    ON "saved_items"("user_id", "collection_id", "created_at" DESC);

-- ============================================================
-- P4.2 Post quote
-- ============================================================
CREATE TABLE "post_quotes" (
    "id" UUID NOT NULL,
    "quoting_post_id" UUID NOT NULL,
    "quoted_post_id" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "post_quotes_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "post_quotes_quoting_post_id_key"
    ON "post_quotes"("quoting_post_id");

CREATE INDEX "post_quotes_quoted_post_id_created_at_idx"
    ON "post_quotes"("quoted_post_id", "created_at" DESC);

ALTER TABLE "post_quotes"
    ADD CONSTRAINT "post_quotes_quoting_post_id_fkey"
    FOREIGN KEY ("quoting_post_id") REFERENCES "posts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "post_quotes"
    ADD CONSTRAINT "post_quotes_quoted_post_id_fkey"
    FOREIGN KEY ("quoted_post_id") REFERENCES "posts"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;

-- ============================================================
-- P4.3 Follow recommendations cache
-- ============================================================
CREATE TABLE "follow_recommendations" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "recommended_user_id" UUID NOT NULL,
    "score" DOUBLE PRECISION NOT NULL,
    "reason" JSONB NOT NULL,
    "computed_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "follow_recommendations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "follow_recommendations_user_id_recommended_user_id_key"
    ON "follow_recommendations"("user_id", "recommended_user_id");

CREATE INDEX "follow_recommendations_user_id_score_idx"
    ON "follow_recommendations"("user_id", "score" DESC);

ALTER TABLE "follow_recommendations"
    ADD CONSTRAINT "follow_recommendations_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "follow_recommendations"
    ADD CONSTRAINT "follow_recommendations_recommended_user_id_fkey"
    FOREIGN KEY ("recommended_user_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- ============================================================
-- P4.6 Weekly digest opt-in
-- ============================================================
ALTER TABLE "notification_preferences"
    ADD COLUMN "weekly_digest_enabled" BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN "weekly_digest_last_sent_at" TIMESTAMPTZ(6);
