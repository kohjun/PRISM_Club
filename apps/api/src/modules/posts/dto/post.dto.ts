import { EventCardDTO, ReferenceDTO } from '../../community/dto/room.dto';

export interface MediaAttachmentTarget {
  id: string;
  kind: 'IMAGE';
  filename: string;
  mime_type: string;
  size_bytes: number;
  url: string;
  created_at: string;
}

export interface PostAttachmentDTO {
  id: string;
  attachment_type: 'EVENT_CARD' | 'REFERENCE' | 'IMAGE';
  target: EventCardDTO | ReferenceDTO | MediaAttachmentTarget;
  sort_order: number;
}

export interface PostAuthorDTO {
  id: string;
  nickname: string;
  avatar_url: string | null;
}

export type PostType = 'GENERAL' | 'RECRUITMENT';

export type RecruitmentStatus = 'OPEN' | 'CLOSED' | 'FILLED';

export interface RecruitmentFieldsDTO {
  role: string;
  schedule: string;
  location: string;
  compensation: string;
  capacity: number;
  application_method: string;
  status: RecruitmentStatus;
}

export interface QuotedPostRefDTO {
  id: string;
  body_preview: string;
  author_nickname: string;
  room_slug: string;
  /** Null when the original was deleted (FK SetNull). */
  available: boolean;
}

export interface PollOptionDTO {
  id: string;
  label: string;
  sort_order: number;
  vote_count: number;
}

export interface PollDTO {
  id: string;
  question: string;
  expires_at: string | null;
  allow_multiple: boolean;
  status: 'OPEN' | 'CLOSED';
  options: PollOptionDTO[];
  total_votes: number;
  my_vote_option_ids: string[];
}

/**
 * P6.4 reaction palette identifiers. The string union is duplicated
 * from `reaction.service.ts:REACTION_TYPES` so DTO consumers don't
 * need a service import.
 */
export type ReactionType =
  | 'HEART'
  | 'THUMBS_UP'
  | 'FIRE'
  | 'THINK'
  | 'IDEA'
  | 'LAUGH';

/**
 * P6.7 reply gate.
 *   ANYONE          — default (legacy behaviour)
 *   FOLLOWERS       — viewer must follow the post author
 *   MENTIONED_ONLY  — viewer must be @-mentioned in the body OR be the author
 *   DISABLED        — only the author can reply (self-thread mode)
 */
export type ReplyPolicy =
  | 'ANYONE'
  | 'FOLLOWERS'
  | 'MENTIONED_ONLY'
  | 'DISABLED';

export interface PostDTO {
  id: string;
  room: { id: string; slug: string; name: string };
  author: PostAuthorDTO;
  body: string;
  status: string;
  post_type: PostType;
  recruitment_fields: RecruitmentFieldsDTO | null;
  created_at: string;
  updated_at: string;
  attachments: PostAttachmentDTO[];
  counts: { reply_count: number; like_count: number; boost_count: number };
  /**
   * Backwards-compatible flag: true when viewer reacted with ANY
   * emoji on this target. Old UI keeps working unchanged.
   */
  liked_by_me: boolean;
  /** P6.6: true when viewer has boosted this post. */
  boosted_by_me: boolean;
  /**
   * P6.4: the specific emoji the viewer chose, or null when the
   * viewer has not reacted. Used by the reaction palette to
   * highlight the active selection.
   */
  my_reaction: ReactionType | null;
  /** P4.2: the post this one quotes, or null if it is not a quoter. */
  quoted_post: QuotedPostRefDTO | null;
  /** P6.5: poll sidecar (1:1 with the post) or null. */
  poll: PollDTO | null;
  /** P6.7 reply gate. ANYONE / FOLLOWERS / MENTIONED_ONLY / DISABLED. */
  reply_policy: ReplyPolicy;
}

export interface ReplyDTO {
  id: string;
  post_id: string;
  parent_reply_id: string | null;
  author: PostAuthorDTO;
  body: string;
  status: string;
  created_at: string;
  updated_at: string;
  like_count: number;
  liked_by_me: boolean;
  /** P6.4: viewer's emoji reaction, or null. See PostDTO.my_reaction. */
  my_reaction: ReactionType | null;
}
