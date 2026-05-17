-- CreateTable
CREATE TABLE "analytics_events" (
    "id" UUID NOT NULL,
    "actor_id" UUID,
    "event_type" TEXT NOT NULL,
    "payload" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "analytics_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "analytics_events_event_type_created_at_idx" ON "analytics_events"("event_type", "created_at" DESC);

-- CreateIndex
CREATE INDEX "analytics_events_actor_id_created_at_idx" ON "analytics_events"("actor_id", "created_at" DESC);
