-- P7.1 Topic Hub similarity recommendations.
--
-- Persists hub→hub Jaccard scores so the "이 Hub를 보는 사람들이 같이
-- 가는 Hub" surface on the Topic Hub screen can resolve without
-- recomputing similarity on every request. Computed daily by the
-- `TopicHubSimilarityCron` (advisory lock 854_305) and refreshed
-- on-demand by an admin-only ops endpoint.
--
-- Score combines two signals (deterministic + explainable):
--   - contributor overlap (KnowledgeBlockRevision.changedBy ∪
--     KnowledgeContribution.contributor for APPROVED status)
--   - room overlap (rooms via hub.category.rooms)
-- Final score = 0.7 * contributorJaccard + 0.3 * roomJaccard so the
-- knowledge signal (Club's primary asset) outweighs the room signal.
-- `reason` is a small jsonb so the API can surface the human-readable
-- "왜 이 Hub가 추천됐는가" copy on the mobile card.

CREATE TABLE "topic_hub_similarity" (
    "id" UUID NOT NULL,
    "topic_hub_id" UUID NOT NULL,
    "similar_hub_id" UUID NOT NULL,
    "score" DOUBLE PRECISION NOT NULL,
    "reason" JSONB NOT NULL,
    "computed_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "topic_hub_similarity_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "topic_hub_similarity_topic_hub_id_similar_hub_id_key"
    ON "topic_hub_similarity"("topic_hub_id", "similar_hub_id");

CREATE INDEX "topic_hub_similarity_topic_hub_id_score_idx"
    ON "topic_hub_similarity"("topic_hub_id", "score" DESC);

ALTER TABLE "topic_hub_similarity"
    ADD CONSTRAINT "topic_hub_similarity_topic_hub_id_fkey"
    FOREIGN KEY ("topic_hub_id") REFERENCES "topic_hubs"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "topic_hub_similarity"
    ADD CONSTRAINT "topic_hub_similarity_similar_hub_id_fkey"
    FOREIGN KEY ("similar_hub_id") REFERENCES "topic_hubs"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
