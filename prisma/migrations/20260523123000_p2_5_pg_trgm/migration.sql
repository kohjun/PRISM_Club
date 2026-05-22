-- P2.5 Korean search upgrade — enable pg_trgm and emit GIN trigram
-- indexes on every text column the search service hits.
--
-- pg_trgm's trigram operators (`%`, `<%`, `<<%`) AND the existing
-- ILIKE queries the SearchService already issues are both accelerated
-- by these indexes, so the upgrade is observable as a latency drop
-- with zero service-code change. The score-based ranking (raw
-- similarity() ORDER BY) lands in a follow-up.
--
-- Production note: CREATE EXTENSION may require superuser on managed
-- Postgres (RDS, Cloud SQL). If you hit "permission denied" run it
-- once manually as the superuser before applying this migration via
-- `prisma migrate deploy`.

-- Extension
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Topic hub
CREATE INDEX IF NOT EXISTS "idx_topic_hubs_title_trgm"
    ON "topic_hubs" USING gin ("title" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS "idx_topic_hubs_summary_trgm"
    ON "topic_hubs" USING gin ("summary" gin_trgm_ops);

-- Knowledge blocks
CREATE INDEX IF NOT EXISTS "idx_knowledge_blocks_title_trgm"
    ON "knowledge_blocks" USING gin ("title" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS "idx_knowledge_blocks_body_trgm"
    ON "knowledge_blocks" USING gin ("body" gin_trgm_ops);

-- Rooms
CREATE INDEX IF NOT EXISTS "idx_rooms_name_trgm"
    ON "rooms" USING gin ("name" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS "idx_rooms_description_trgm"
    ON "rooms" USING gin ("description" gin_trgm_ops)
    WHERE "description" IS NOT NULL;

-- Posts
CREATE INDEX IF NOT EXISTS "idx_posts_body_trgm"
    ON "posts" USING gin ("body" gin_trgm_ops);

-- Event cards
CREATE INDEX IF NOT EXISTS "idx_event_cards_title_trgm"
    ON "event_cards" USING gin ("title" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS "idx_event_cards_venue_name_trgm"
    ON "event_cards" USING gin ("venue_name" gin_trgm_ops);

-- Reference items
CREATE INDEX IF NOT EXISTS "idx_reference_items_title_trgm"
    ON "reference_items" USING gin ("title" gin_trgm_ops);
CREATE INDEX IF NOT EXISTS "idx_reference_items_summary_trgm"
    ON "reference_items" USING gin ("summary" gin_trgm_ops)
    WHERE "summary" IS NOT NULL;
