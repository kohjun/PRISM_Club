-- P3.1 EventRsvp — per-user RSVP per event card.

-- CreateTable
CREATE TABLE "event_rsvps" (
    "id" UUID NOT NULL,
    "event_card_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "event_rsvps_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "event_rsvps_event_card_id_user_id_key"
    ON "event_rsvps"("event_card_id", "user_id");

-- CreateIndex
CREATE INDEX "event_rsvps_user_id_updated_at_idx"
    ON "event_rsvps"("user_id", "updated_at" DESC);

-- CreateIndex
CREATE INDEX "event_rsvps_event_card_id_status_idx"
    ON "event_rsvps"("event_card_id", "status");

-- AddForeignKey
ALTER TABLE "event_rsvps"
    ADD CONSTRAINT "event_rsvps_event_card_id_fkey"
    FOREIGN KEY ("event_card_id") REFERENCES "event_cards"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_rsvps"
    ADD CONSTRAINT "event_rsvps_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
