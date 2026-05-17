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
