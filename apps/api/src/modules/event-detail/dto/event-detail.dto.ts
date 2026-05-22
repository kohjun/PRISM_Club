import { PostDTO } from '../../posts/dto/post.dto';
import { EventCardDTO } from '../../community/dto/room.dto';
import { EventReviewDTO } from './review.dto';

export interface RelatedRoomDTO {
  id: string;
  slug: string;
  name: string;
  origin: string;       // OFFICIAL | USER
  room_type: string;
  owner_nickname: string | null;
  relation: 'PIN' | 'POST_ATTACHMENT';
}

export interface RelatedPostsPageDTO {
  items: PostDTO[];
  next_cursor: string | null;
}

export interface EventDetailBundleDTO {
  event_card: EventCardDTO;
  related_rooms: RelatedRoomDTO[];
  related_posts: RelatedPostsPageDTO;
  default_compose_room_slug: string | null;
  /**
   * P3.3: top-N reviews surfaced inline. Empty array when the event
   * isn't COMPLETED yet or no one has reviewed.
   */
  verified_reviews: EventReviewDTO[];
  counts: {
    post_count: number;
    room_count: number;
    review_count: number;
    review_average: number | null;
  };
  /** P3.1 RSVP state for the calling viewer. */
  rsvp: {
    my_status: 'INTERESTED' | 'GOING' | 'ATTENDED' | null;
    counts: {
      interested: number;
      going: number;
      attended: number;
    };
  };
}
