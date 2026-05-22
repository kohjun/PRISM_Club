-- P3.6 Recruitment application tracking.
-- Adds the two structured tables that replace the loose
-- Post.recruitment_fields JSON for canonical status + capacity +
-- per-applicant lifecycle.

-- CreateTable
CREATE TABLE "recruitment_posts" (
    "post_id" UUID NOT NULL,
    "capacity" INTEGER,
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "deadline_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "recruitment_posts_pkey" PRIMARY KEY ("post_id")
);

-- AddForeignKey
ALTER TABLE "recruitment_posts"
    ADD CONSTRAINT "recruitment_posts_post_id_fkey"
    FOREIGN KEY ("post_id") REFERENCES "posts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "recruitment_applications" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "applicant_id" UUID NOT NULL,
    "message" TEXT,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "recruitment_applications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "recruitment_applications_post_id_applicant_id_key"
    ON "recruitment_applications"("post_id", "applicant_id");

-- CreateIndex
CREATE INDEX "recruitment_applications_applicant_id_created_at_idx"
    ON "recruitment_applications"("applicant_id", "created_at" DESC);

-- AddForeignKey
ALTER TABLE "recruitment_applications"
    ADD CONSTRAINT "recruitment_applications_post_id_fkey"
    FOREIGN KEY ("post_id") REFERENCES "recruitment_posts"("post_id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "recruitment_applications"
    ADD CONSTRAINT "recruitment_applications_applicant_id_fkey"
    FOREIGN KEY ("applicant_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- Backfill: every existing RECRUITMENT post gets a structured row.
-- We default to OPEN with NULL capacity/deadline; planners can edit
-- via the new admin UI. Pre-existing Post.recruitment_fields JSON
-- stays in place during the dual-write window (PostService keeps
-- writing both for a release), so the mobile that still reads the
-- JSON path keeps working.
INSERT INTO "recruitment_posts" (
    "post_id",
    "capacity",
    "status",
    "deadline_at",
    "updated_at",
    "created_at"
)
SELECT
    "id",
    NULLIF((recruitment_fields ->> 'capacity'), '')::int,
    COALESCE(recruitment_fields ->> 'status', 'OPEN'),
    NULLIF(recruitment_fields ->> 'deadline_at', '')::timestamptz,
    CURRENT_TIMESTAMP,
    "created_at"
FROM "posts"
WHERE "post_type" = 'RECRUITMENT';
