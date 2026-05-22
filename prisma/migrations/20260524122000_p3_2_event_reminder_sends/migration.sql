-- P3.2 Event reminder dedup table.
-- One row per (event, user, reminder_kind). Unique constraint is the
-- canonical "already sent" check the cron consults before notifying.

-- CreateTable
CREATE TABLE "event_reminder_sends" (
    "id" UUID NOT NULL,
    "event_card_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "reminder_kind" TEXT NOT NULL,
    "sent_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_reminder_sends_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "event_reminder_sends_event_card_id_user_id_reminder_kind_key"
    ON "event_reminder_sends"("event_card_id", "user_id", "reminder_kind");

-- CreateIndex
CREATE INDEX "event_reminder_sends_event_card_id_reminder_kind_idx"
    ON "event_reminder_sends"("event_card_id", "reminder_kind");

-- AddForeignKey
ALTER TABLE "event_reminder_sends"
    ADD CONSTRAINT "event_reminder_sends_event_card_id_fkey"
    FOREIGN KEY ("event_card_id") REFERENCES "event_cards"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_reminder_sends"
    ADD CONSTRAINT "event_reminder_sends_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
