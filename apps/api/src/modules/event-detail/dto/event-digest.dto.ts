export interface EventDigestTopPostDTO {
  id: string;
  snippet: string;
  room_slug: string;
  like_count: number;
  reply_count: number;
}

export interface EventDigestTopReviewDTO {
  id: string;
  rating: number;
  snippet: string;
  user_nickname: string | null;
  created_at: string;
}

export interface EventDigestPayloadV1 {
  schemaVersion: 1;
  topPosts: EventDigestTopPostDTO[];
  topReviews: EventDigestTopReviewDTO[];
  reviewCount: number;
  averageRating: number | null;
  spaceAccessPolicy: string;
}

export interface EventDigestDTO {
  event_card_id: string;
  period_start: string;
  period_end: string;
  generated_at: string;
  payload: EventDigestPayloadV1;
}
