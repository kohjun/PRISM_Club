-- P2.2 Contribution reputation aggregate table.
-- Lazily updated inside the contribution-resolve transaction; one row
-- per contributor that has resolved at least one contribution.

-- CreateTable
CREATE TABLE "contribution_reputation" (
    "user_id" UUID NOT NULL,
    "approved_count" INTEGER NOT NULL DEFAULT 0,
    "rejected_count" INTEGER NOT NULL DEFAULT 0,
    "needs_changes_count" INTEGER NOT NULL DEFAULT 0,
    "withdrawn_count" INTEGER NOT NULL DEFAULT 0,
    "weighted_score" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "last_resolved_at" TIMESTAMPTZ(6),
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "contribution_reputation_pkey" PRIMARY KEY ("user_id")
);

-- CreateIndex
CREATE INDEX "contribution_reputation_weighted_score_idx"
    ON "contribution_reputation"("weighted_score" DESC);

-- AddForeignKey
ALTER TABLE "contribution_reputation"
    ADD CONSTRAINT "contribution_reputation_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- Backfill: aggregate every contributor's history once so the leaderboard
-- and profile badges start populated. Future resolves keep the row in
-- sync incrementally.
INSERT INTO "contribution_reputation" (
    "user_id",
    "approved_count",
    "rejected_count",
    "needs_changes_count",
    "withdrawn_count",
    "weighted_score",
    "last_resolved_at",
    "updated_at",
    "created_at"
)
SELECT
    "contributor_id" AS user_id,
    COUNT(*) FILTER (WHERE "status" = 'APPROVED')      AS approved_count,
    COUNT(*) FILTER (WHERE "status" = 'REJECTED')      AS rejected_count,
    COUNT(*) FILTER (WHERE "status" = 'NEEDS_CHANGES') AS needs_changes_count,
    COUNT(*) FILTER (WHERE "status" = 'WITHDRAWN')     AS withdrawn_count,
    GREATEST(
        0::numeric,
          COUNT(*) FILTER (WHERE "status" = 'APPROVED')      * 3
        - COUNT(*) FILTER (WHERE "status" = 'REJECTED')      * 1
        - COUNT(*) FILTER (WHERE "status" = 'NEEDS_CHANGES') * 0.5
        - COUNT(*) FILTER (WHERE "status" = 'WITHDRAWN')     * 0.2
    )::decimal(10,2) AS weighted_score,
    MAX("resolved_at") AS last_resolved_at,
    CURRENT_TIMESTAMP AS updated_at,
    CURRENT_TIMESTAMP AS created_at
FROM "knowledge_contributions"
GROUP BY "contributor_id";
