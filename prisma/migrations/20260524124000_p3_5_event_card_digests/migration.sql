-- P3.5 Per-event recap digest — pattern mirrors topic_hub_digests.

-- CreateTable
CREATE TABLE "event_card_digests" (
    "id" UUID NOT NULL,
    "event_card_id" UUID NOT NULL,
    "period_start" TIMESTAMPTZ(6) NOT NULL,
    "period_end" TIMESTAMPTZ(6) NOT NULL,
    "payload" JSONB NOT NULL,
    "generated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_card_digests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "event_card_digests_event_card_id_period_start_key"
    ON "event_card_digests"("event_card_id", "period_start");

-- AddForeignKey
ALTER TABLE "event_card_digests"
    ADD CONSTRAINT "event_card_digests_event_card_id_fkey"
    FOREIGN KEY ("event_card_id") REFERENCES "event_cards"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
