-- P7.2 Knowledge validation strength + contribution chain.
--
-- Surface-side this PR adds two new endpoints — `validation` and
-- `chain` — both backed by read-time computation over existing data
-- (KnowledgeBlockRevision + KnowledgeContribution + ContributionReputation).
-- No new columns or tables; the only structural change here is a
-- supporting index so the per-block "count APPROVED contributions"
-- subquery doesn't hot-scan the contributions table on every read.

CREATE INDEX "knowledge_contributions_target_status_idx"
    ON "knowledge_contributions"("target_block_id", "status");
