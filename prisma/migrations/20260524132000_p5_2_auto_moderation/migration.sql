-- P5.2 auto-moderation: rule catalog + post/report stamps + seed.

-- AlterTable
ALTER TABLE "posts"
    ADD COLUMN "auto_moderated_at" TIMESTAMPTZ(6),
    ADD COLUMN "auto_moderation_reason" TEXT;

ALTER TABLE "reports"
    ADD COLUMN "auto_dismissed_reason" TEXT;

-- CreateTable
CREATE TABLE "auto_moderation_rules" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "params" JSONB NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "auto_moderation_rules_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "auto_moderation_rules_kind_key"
    ON "auto_moderation_rules"("kind");

-- Seed the canonical rule set so the service has thresholds to
-- consult on first boot. Admins can adjust `params` later via a
-- future admin tool without a schema change.
INSERT INTO "auto_moderation_rules" ("id", "name", "kind", "params", "enabled", "updated_at") VALUES
    (
        gen_random_uuid(),
        '24시간 내 동일 본문 게시 차단',
        'DUPLICATE_POST_HASH',
        '{"window_hours": 24, "threshold": 2}'::jsonb,
        true,
        CURRENT_TIMESTAMP
    ),
    (
        gen_random_uuid(),
        '신고 폭주 자동 차단',
        'REPORT_FLOOD',
        '{"window_hours": 1, "threshold": 10}'::jsonb,
        true,
        CURRENT_TIMESTAMP
    );
