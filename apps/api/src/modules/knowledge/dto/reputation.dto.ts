export interface ReputationDTO {
  user_id: string;
  approved_count: number;
  rejected_count: number;
  needs_changes_count: number;
  withdrawn_count: number;
  weighted_score: number;
  last_resolved_at: string | null;
  /** Optional 1-based rank by weighted_score, only set on the leaderboard endpoint. */
  rank?: number;
}

export interface ReputationLeaderboardEntryDTO extends ReputationDTO {
  rank: number;
  user: {
    id: string;
    nickname: string | null;
  };
}

export interface ReputationLeaderboardDTO {
  items: ReputationLeaderboardEntryDTO[];
  computed_at: string;
}
