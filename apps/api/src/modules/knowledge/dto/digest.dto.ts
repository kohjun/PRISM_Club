export interface DigestRevisionDTO {
  block_id: string;
  version: number;
  block_type: string;
  title: string;
  contributor_nickname: string | null;
  changed_at: string;
}

export interface DigestReferenceDTO {
  id: string;
  title: string;
  source_tier: string;
  source_name: string | null;
  url: string;
}

export interface DigestEventDTO {
  id: string;
  title: string;
  venue_name: string;
  region: string;
  starts_at: string;
  thumbnail_url: string | null;
}

export interface DigestPostDTO {
  id: string;
  snippet: string;
  room_slug: string;
  like_count: number;
  reply_count: number;
}

export interface DigestPayloadV1 {
  schemaVersion: 1;
  revisions: DigestRevisionDTO[];
  newReferences: DigestReferenceDTO[];
  newEvents: DigestEventDTO[];
  popularPosts: DigestPostDTO[];
  spaceAccessPolicy: string;
}

export interface TopicHubDigestDTO {
  topic_hub_id: string;
  category_slug: string;
  period_start: string;
  period_end: string;
  generated_at: string;
  payload: DigestPayloadV1;
}

export interface DigestRefreshSummaryDTO {
  period_start: string;
  period_end: string;
  hubs_processed: number;
  digests_written: number;
  empty_hubs: number;
}
