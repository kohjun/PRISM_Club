-- P6.5 polls.
--
-- A poll is a 1:1 sidecar on a post — the post body is the question
-- preamble + opinion, the poll row carries the structured options.
-- Multi-choice support is opt-in per poll; default is single-choice.

-- CreateTable: polls
CREATE TABLE "polls" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "question" TEXT NOT NULL,
    "expires_at" TIMESTAMPTZ(6),
    "allow_multiple" BOOLEAN NOT NULL DEFAULT false,
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "polls_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "polls_post_id_key" ON "polls"("post_id");

ALTER TABLE "polls"
    ADD CONSTRAINT "polls_post_id_fkey"
    FOREIGN KEY ("post_id") REFERENCES "posts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateTable: poll_options
CREATE TABLE "poll_options" (
    "id" UUID NOT NULL,
    "poll_id" UUID NOT NULL,
    "label" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "poll_options_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "poll_options_poll_id_idx" ON "poll_options"("poll_id", "sort_order");

ALTER TABLE "poll_options"
    ADD CONSTRAINT "poll_options_poll_id_fkey"
    FOREIGN KEY ("poll_id") REFERENCES "polls"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateTable: poll_votes
CREATE TABLE "poll_votes" (
    "id" UUID NOT NULL,
    "poll_id" UUID NOT NULL,
    "option_id" UUID NOT NULL,
    "voter_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "poll_votes_pkey" PRIMARY KEY ("id")
);

-- Single-choice polls: a voter holds at most one row per poll. The
-- service-layer guard rejects a 2nd vote for single-choice polls
-- before INSERT, but the unique on (poll, voter, option) below still
-- catches duplicate (option) votes on multi-choice polls.
CREATE UNIQUE INDEX "poll_votes_poll_voter_option_unique"
    ON "poll_votes"("poll_id", "voter_id", "option_id");

CREATE INDEX "poll_votes_option_idx" ON "poll_votes"("option_id");
CREATE INDEX "poll_votes_voter_idx" ON "poll_votes"("voter_id");

ALTER TABLE "poll_votes"
    ADD CONSTRAINT "poll_votes_poll_id_fkey"
    FOREIGN KEY ("poll_id") REFERENCES "polls"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "poll_votes"
    ADD CONSTRAINT "poll_votes_option_id_fkey"
    FOREIGN KEY ("option_id") REFERENCES "poll_options"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "poll_votes"
    ADD CONSTRAINT "poll_votes_voter_id_fkey"
    FOREIGN KEY ("voter_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
