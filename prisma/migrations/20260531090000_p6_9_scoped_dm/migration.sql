-- P6.9 Scoped DM — workflow-bounded private 1:1 channels.
--
-- Two scopes only (no open DM): RECRUITMENT (applicant ↔ post author)
-- and CONTRIBUTION (proposer ↔ the curator who set NEEDS_CHANGES).
-- party_a is role-canonicalized to the applicant/proposer and party_b
-- to the author/curator, so UNIQUE(scope, ref_id, party_a_id) is the
-- tightest correct key for both scopes (party_b is derived, never part
-- of the key). Channels are closed by the lifecycle cron at
-- workflow-end + 30d grace and are NEVER hard-deleted — a reported
-- message must remain resolvable by a moderator even after close.

CREATE TABLE "dm_channels" (
    "id" UUID NOT NULL,
    "scope" TEXT NOT NULL,
    "ref_id" UUID NOT NULL,
    "party_a_id" UUID NOT NULL,
    "party_b_id" UUID NOT NULL,
    "space_access_policy" TEXT NOT NULL DEFAULT 'PUBLIC',
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "workflow_ended_at" TIMESTAMPTZ(6),
    "last_message_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "closed_at" TIMESTAMPTZ(6),
    "closed_reason" TEXT,

    CONSTRAINT "dm_channels_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "dm_channels_no_self" CHECK ("party_a_id" <> "party_b_id")
);

CREATE UNIQUE INDEX "dm_channels_scope_ref_id_party_a_id_key"
    ON "dm_channels"("scope", "ref_id", "party_a_id");

CREATE INDEX "dm_channels_party_a_id_last_message_at_idx"
    ON "dm_channels"("party_a_id", "last_message_at" DESC);

CREATE INDEX "dm_channels_party_b_id_last_message_at_idx"
    ON "dm_channels"("party_b_id", "last_message_at" DESC);

-- Partial index for the lifecycle cron's OPEN-channel sweep (Prisma's
-- @@index cannot express a WHERE clause, so it lives only here).
CREATE INDEX "dm_channels_open_idx"
    ON "dm_channels"("workflow_ended_at")
    WHERE "status" = 'OPEN';

ALTER TABLE "dm_channels" ADD CONSTRAINT "dm_channels_party_a_id_fkey"
    FOREIGN KEY ("party_a_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "dm_channels" ADD CONSTRAINT "dm_channels_party_b_id_fkey"
    FOREIGN KEY ("party_b_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "dm_messages" (
    "id" UUID NOT NULL,
    "channel_id" UUID NOT NULL,
    "sender_id" UUID NOT NULL,
    "body" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'VISIBLE',
    "auto_moderation_reason" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "read_by_recipient_at" TIMESTAMPTZ(6),

    CONSTRAINT "dm_messages_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "dm_messages_channel_id_created_at_idx"
    ON "dm_messages"("channel_id", "created_at" DESC);

ALTER TABLE "dm_messages" ADD CONSTRAINT "dm_messages_channel_id_fkey"
    FOREIGN KEY ("channel_id") REFERENCES "dm_channels"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "dm_messages" ADD CONSTRAINT "dm_messages_sender_id_fkey"
    FOREIGN KEY ("sender_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
