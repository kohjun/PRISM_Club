export type RecruitmentApplicationStatus =
  | 'PENDING'
  | 'ACCEPTED'
  | 'REJECTED'
  | 'WITHDRAWN';

export interface RecruitmentApplicationDTO {
  id: string;
  post_id: string;
  applicant: { id: string; nickname: string | null };
  message: string | null;
  status: RecruitmentApplicationStatus;
  created_at: string;
  updated_at: string;
}

export interface MyApplicationEntryDTO {
  application: RecruitmentApplicationDTO;
  post: {
    id: string;
    body_preview: string;
    room_slug: string;
    status: string;
  };
}

export interface MyApplicationsListDTO {
  items: MyApplicationEntryDTO[];
  next_cursor: string | null;
}

export interface ApplicationsListDTO {
  items: RecruitmentApplicationDTO[];
  next_cursor: string | null;
  recruitment_status: string;
  accepted_count: number;
  capacity: number | null;
}
