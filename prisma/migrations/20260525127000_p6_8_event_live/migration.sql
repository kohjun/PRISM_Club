-- P6.8 event "현장 라이브" (live mode).
--
-- Short-form posts attached to an EventCard, writable only while the
-- event is IN_PROGRESS (starts_at .. starts_at + 4h) and only by
-- viewers whose RSVP is ATTENDED. Auto-archives 48h after starts_at
-- via a background cron — archived rows still exist for audit but
-- drop out of the "현장 라이브" strip surface.

CREATE TABLE "event_live_posts" (
    "id" UUID NOT NULL,
    "event_card_id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "body" TEXT NOT NULL,
    "image_media_id" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "archived_at" TIMESTAMPTZ(6),

    CONSTRAINT "event_live_posts_pkey" PRIMARY KEY ("id")
);

-- Hot read path: the EventDetail "현장 라이브" strip queries by
-- (event_card_id) ordered by recency with archived_at IS NULL.
CREATE INDEX "event_live_posts_card_idx"
    ON "event_live_posts"("event_card_id", "archived_at", "created_at" DESC);

-- "Has this user posted live during this event" lookup (UI dedupes).
CREATE INDEX "event_live_posts_author_idx"
    ON "event_live_posts"("author_id", "created_at" DESC);

ALTER TABLE "event_live_posts"
    ADD CONSTRAINT "event_live_posts_event_card_id_fkey"
    FOREIGN KEY ("event_card_id") REFERENCES "event_cards"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "event_live_posts"
    ADD CONSTRAINT "event_live_posts_author_id_fkey"
    FOREIGN KEY ("author_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "event_live_posts"
    ADD CONSTRAINT "event_live_posts_image_media_id_fkey"
    FOREIGN KEY ("image_media_id") REFERENCES "media_assets"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
