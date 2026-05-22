-- P3.3 Event reviews — per-user review per completed event.

-- CreateTable
CREATE TABLE "event_reviews" (
    "id" UUID NOT NULL,
    "event_card_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "rating" INTEGER NOT NULL,
    "body" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'VISIBLE',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "event_reviews_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "event_reviews_event_card_id_user_id_key"
    ON "event_reviews"("event_card_id", "user_id");

-- CreateIndex
CREATE INDEX "event_reviews_event_card_id_created_at_idx"
    ON "event_reviews"("event_card_id", "created_at" DESC);

-- AddForeignKey
ALTER TABLE "event_reviews"
    ADD CONSTRAINT "event_reviews_event_card_id_fkey"
    FOREIGN KEY ("event_card_id") REFERENCES "event_cards"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_reviews"
    ADD CONSTRAINT "event_reviews_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
