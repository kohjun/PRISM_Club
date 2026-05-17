import { PostDTO } from '../../posts/dto/post.dto';
import { RoomSummaryDTO, EventCardDTO } from '../../community/dto/room.dto';
import { SavedItemDTO } from '../../saves/save.service';

export interface TopicHubSummaryDTO {
  id: string;
  category_slug: string;
  title: string;
  summary: string | null;
  block_count: number;
  updated_at: string;
}

export type HomeFeedItemType =
  | 'FOLLOWED_ROOM_POST'
  | 'TRENDING_POST'
  | 'RECOMMENDED_ROOM'
  | 'RECOMMENDED_EVENT'
  | 'ACTIVE_HUB';

export interface HomeFeedItemDTO {
  id: string;
  type: HomeFeedItemType;
  reason: string;
  payload: PostDTO | RoomSummaryDTO | EventCardDTO | TopicHubSummaryDTO;
}

export interface HomeFeedPageDTO {
  items: HomeFeedItemDTO[];
  next_cursor: string | null;
}

export interface HomeBundleDTO {
  unread_notification_count: number;
  followed_room_updates: PostDTO[];
  recommended_rooms: RoomSummaryDTO[];
  recommended_events: EventCardDTO[];
  trending_posts: PostDTO[];
  active_topic_hubs: TopicHubSummaryDTO[];
  saved_recently: SavedItemDTO[];
}
