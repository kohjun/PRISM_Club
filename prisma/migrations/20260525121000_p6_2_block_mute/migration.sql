-- P6.2 user-level block + mute.
--
-- Block is bidirectional in effect (blocker hides blocked, blocked can't
-- write to / mention / follow blocker). Mute is unidirectional (muter
-- hides from feed + notifications, mutee is unaware).
--
-- Both rows are user-pair primitives — neither targets posts/rooms.

-- CreateTable: user_blocks
CREATE TABLE "user_blocks" (
    "blocker_id" UUID NOT NULL,
    "blocked_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_blocks_pkey" PRIMARY KEY ("blocker_id", "blocked_id")
);

-- Reverse lookup for "who blocks me" — used by write-side guards.
CREATE INDEX "user_blocks_blocked_idx"
    ON "user_blocks"("blocked_id");

ALTER TABLE "user_blocks"
    ADD CONSTRAINT "user_blocks_blocker_id_fkey"
    FOREIGN KEY ("blocker_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "user_blocks"
    ADD CONSTRAINT "user_blocks_blocked_id_fkey"
    FOREIGN KEY ("blocked_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- Self-block is a no-op; the service layer 400s the request, but a
-- check constraint catches direct SQL too.
ALTER TABLE "user_blocks"
    ADD CONSTRAINT "user_blocks_no_self_block"
    CHECK ("blocker_id" <> "blocked_id");

-- CreateTable: user_mutes
CREATE TABLE "user_mutes" (
    "muter_id" UUID NOT NULL,
    "muted_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_mutes_pkey" PRIMARY KEY ("muter_id", "muted_id")
);

-- "Who am I muting" is the only query direction (mute is one-way), so
-- the PK doubles as the primary index.

ALTER TABLE "user_mutes"
    ADD CONSTRAINT "user_mutes_muter_id_fkey"
    FOREIGN KEY ("muter_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "user_mutes"
    ADD CONSTRAINT "user_mutes_muted_id_fkey"
    FOREIGN KEY ("muted_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "user_mutes"
    ADD CONSTRAINT "user_mutes_no_self_mute"
    CHECK ("muter_id" <> "muted_id");
