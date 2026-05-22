import { PostDTO } from '../../posts/dto/post.dto';
import { RoomSummaryDTO } from '../../community/dto/room.dto';

export interface UserProfileBundleDTO {
  user: {
    id: string;
    nickname: string | null;
    avatar_url: string | null;
    status: string;
    created_at: string;
  };
  profile: {
    bio: string | null;
    region: string | null;
    interests: string[];
  };
  roles: string[];
  counts: {
    post_count: number;
    room_count: number;
    follower_count: number;
    following_count: number;
  };
  recent_posts: PostDTO[];
  user_rooms: RoomSummaryDTO[];
  approved_contributions: ApprovedContributionDTO[];
  is_self: boolean;
  is_following: boolean;
}

export interface ApprovedContributionDTO {
  id: string;
  topic_hub_title: string;
  category_slug: string;
  decision: 'APPROVED';
  resolved_at: string;
}

export interface UpdateProfileInput {
  bio?: string | null;
  region?: string | null;
  interests?: string[];
  /** P-F15: rename. Unique across all users; 2..20 chars Korean/Latin/digit. */
  nickname?: string;
  /** P-F15: profile avatar. Null clears the current avatar. */
  avatar_url?: string | null;
}

export interface ProfileSubDTO {
  bio: string | null;
  region: string | null;
  interests: string[];
  nickname: string;
  avatar_url: string | null;
}

export interface FollowStateDTO {
  followed: boolean;
  follower_count: number;
}
