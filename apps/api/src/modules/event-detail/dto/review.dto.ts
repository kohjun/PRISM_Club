export interface EventReviewDTO {
  id: string;
  event_card_id: string;
  user: { id: string; nickname: string | null };
  rating: number;
  body: string;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface EventReviewsListDTO {
  items: EventReviewDTO[];
  next_cursor: string | null;
  average_rating: number | null;
  total: number;
}
