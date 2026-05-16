import { EventCardDTO, ReferenceDTO } from '../../community/dto/room.dto';

export interface PostAttachmentDTO {
  id: string;
  attachment_type: 'EVENT_CARD' | 'REFERENCE';
  target: EventCardDTO | ReferenceDTO;
  sort_order: number;
}

export interface PostAuthorDTO {
  id: string;
  nickname: string;
  avatar_url: string | null;
}

export interface PostDTO {
  id: string;
  room: { id: string; slug: string; name: string };
  author: PostAuthorDTO;
  body: string;
  status: string;
  created_at: string;
  updated_at: string;
  attachments: PostAttachmentDTO[];
  counts: { reply_count: number; like_count: number };
  liked_by_me: boolean;
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
}
