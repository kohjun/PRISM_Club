-- P6.6 repost (boost).
--
-- A boost is a "share without comment" amplify. Distinct from quote
-- (P4.2) which requires a new post body. A user holds at most one
-- boost per post; double-tap = remove.
--
-- Denormalised counter on posts.boost_count keeps the home feed
-- ordering query O(1) per post.

ALTER TABLE "posts"
    ADD COLUMN "boost_count" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE "post_boosts" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "booster_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "post_boosts_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "post_boosts_post_booster_unique"
    ON "post_boosts"("post_id", "booster_id");

-- "Boosts by user" feed (profile timeline) — ordered by recency.
CREATE INDEX "post_boosts_booster_idx"
    ON "post_boosts"("booster_id", "created_at" DESC);

ALTER TABLE "post_boosts"
    ADD CONSTRAINT "post_boosts_post_id_fkey"
    FOREIGN KEY ("post_id") REFERENCES "posts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "post_boosts"
    ADD CONSTRAINT "post_boosts_booster_id_fkey"
    FOREIGN KEY ("booster_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
