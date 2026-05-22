-- P6.4 multi-emoji reactions.
--
-- A user now holds at most ONE reaction per (target_type, target_id) —
-- changing reaction means UPDATEing the reaction_type column. The
-- previous unique on (user, target, type) allowed parallel reactions
-- of different types from the same user, which would skew counts.
--
-- Legacy LIKE rows are migrated to HEART in-place so old UI hits the
-- new HEART bucket without losing engagement signal.

-- Normalize legacy values first so the new unique doesn't collide.
UPDATE "reactions"
SET "reaction_type" = 'HEART'
WHERE "reaction_type" = 'LIKE';

-- Swap the unique constraint.
DROP INDEX IF EXISTS "reactions_user_id_target_type_target_id_reaction_type_key";

CREATE UNIQUE INDEX "reactions_user_target_unique"
    ON "reactions"("user_id", "target_type", "target_id");

-- Update the column default so direct INSERTs without an explicit
-- reaction_type still produce a sensible value.
ALTER TABLE "reactions"
    ALTER COLUMN "reaction_type" SET DEFAULT 'HEART';
