-- P2.3 Reference source tier — adds the source_tier column + the
-- domain-pattern rule table the service consults when classifying new
-- references. Seed rules cover the canonical Korean broadcasters,
-- creator platforms, and major news/community surfaces; everything
-- else stays UNKNOWN until an admin adds a rule.

-- AlterTable
ALTER TABLE "reference_items"
    ADD COLUMN "source_tier" TEXT NOT NULL DEFAULT 'UNKNOWN';

-- CreateTable
CREATE TABLE "reference_source_rules" (
    "id" UUID NOT NULL,
    "domain_pattern" TEXT NOT NULL,
    "tier" TEXT NOT NULL,
    "note" TEXT,
    "created_by" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "reference_source_rules_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "reference_source_rules_domain_pattern_key"
    ON "reference_source_rules"("domain_pattern");

-- AddForeignKey
ALTER TABLE "reference_source_rules"
    ADD CONSTRAINT "reference_source_rules_created_by_fkey"
    FOREIGN KEY ("created_by") REFERENCES "users"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;

-- Seed rules. Tiers:
--   OFFICIAL  — broadcaster / publisher / canonical source.
--   TRUSTED   — major creator platforms and well-known news outlets.
--   COMMUNITY — open forums / blogs / open-creator surfaces.
INSERT INTO "reference_source_rules" ("id", "domain_pattern", "tier", "note") VALUES
    (gen_random_uuid(), 'tving.com',      'OFFICIAL',  'TVING (KR streaming, original broadcast partner)'),
    (gen_random_uuid(), 'wavve.com',      'OFFICIAL',  'wavve (SBS/KBS/MBC joint streaming)'),
    (gen_random_uuid(), 'watcha.com',     'OFFICIAL',  'Watcha (licensed streaming)'),
    (gen_random_uuid(), 'netflix.com',    'OFFICIAL',  'Netflix'),
    (gen_random_uuid(), 'disneyplus.com', 'OFFICIAL',  'Disney+'),
    (gen_random_uuid(), 'coupangplay.com','OFFICIAL',  'Coupang Play'),
    (gen_random_uuid(), 'tvn.co.kr',      'OFFICIAL',  'tvN'),
    (gen_random_uuid(), 'sbs.co.kr',      'OFFICIAL',  'SBS'),
    (gen_random_uuid(), 'kbs.co.kr',      'OFFICIAL',  'KBS'),
    (gen_random_uuid(), 'imbc.com',       'OFFICIAL',  'MBC'),
    (gen_random_uuid(), '*.youtube.com',  'TRUSTED',   'YouTube creator platform'),
    (gen_random_uuid(), 'youtube.com',    'TRUSTED',   'YouTube (apex)'),
    (gen_random_uuid(), 'youtu.be',       'TRUSTED',   'YouTube short link'),
    (gen_random_uuid(), 'chosun.com',     'TRUSTED',   'Chosun Ilbo'),
    (gen_random_uuid(), 'donga.com',      'TRUSTED',   'Donga Ilbo'),
    (gen_random_uuid(), 'hani.co.kr',     'TRUSTED',   'Hankyoreh'),
    (gen_random_uuid(), 'joongang.co.kr', 'TRUSTED',   'JoongAng Ilbo'),
    (gen_random_uuid(), 'naver.com',      'COMMUNITY', 'Naver portal apex'),
    (gen_random_uuid(), '*.naver.com',    'COMMUNITY', 'Naver subdomain (blog/cafe/post)'),
    (gen_random_uuid(), '*.tistory.com',  'COMMUNITY', 'Tistory blog'),
    (gen_random_uuid(), 'brunch.co.kr',   'COMMUNITY', 'Kakao Brunch'),
    (gen_random_uuid(), '*.brunch.co.kr', 'COMMUNITY', 'Kakao Brunch subdomain'),
    (gen_random_uuid(), 'velog.io',       'COMMUNITY', 'Velog blog'),
    (gen_random_uuid(), 'dcinside.com',   'COMMUNITY', 'DCinside gallery'),
    (gen_random_uuid(), '*.dcinside.com', 'COMMUNITY', 'DCinside subdomain'),
    (gen_random_uuid(), 'inven.co.kr',    'COMMUNITY', 'Inven community');
