import { PostDTO } from '../../posts/dto/post.dto';
import { EventCardDTO } from '../../community/dto/room.dto';

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
  verified_reviews: PostDTO[]; // reserved, empty in M5
  counts: {
    post_count: number;
    room_count: number;
  };
}
