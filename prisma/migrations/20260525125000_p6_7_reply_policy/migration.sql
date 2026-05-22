-- P6.7 reply policy gate.
--
-- Adds posts.reply_policy ∈ {ANYONE, FOLLOWERS, MENTIONED_ONLY, DISABLED}.
-- Default ANYONE — existing posts keep their open-to-anyone reply
-- behaviour. ReplyService.create() consults this column on every new
-- reply.

ALTER TABLE "posts"
    ADD COLUMN "reply_policy" TEXT NOT NULL DEFAULT 'ANYONE';
