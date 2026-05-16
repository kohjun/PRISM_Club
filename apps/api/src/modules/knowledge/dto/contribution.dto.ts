import { EventCardDTO, ReferenceDTO } from '../../community/dto/room.dto';

export type ContributionStatus =
  | 'PENDING'
  | 'APPROVED'
  | 'REJECTED'
  | 'NEEDS_CHANGES'
  | 'WITHDRAWN';

export type ContributionEvidenceType = 'EVENT_CARD' | 'REFERENCE';
export type ResolveDecision = 'APPROVE' | 'REJECT' | 'REQUEST_CHANGES';

export interface ContributionSummaryDTO {
  id: string;
  topic_hub_id: string;
  category_slug: string;
  contributor: { id: string; nickname: string };
  target_block_id: string | null;
  proposed_block_type: string;
  proposed_title: string;
  status: ContributionStatus;
  evidence_type: ContributionEvidenceType | null;
  has_evidence: boolean;
  created_at: string;
  resolved_at: string | null;
}

export interface ContributionDetailDTO extends ContributionSummaryDTO {
  proposed_body: string;
  current_block: {
    id: string;
    block_type: string;
    title: string;
    body: string;
  } | null;
  evidence: EventCardDTO | ReferenceDTO | null;
  curator_note: string | null;
  resolver_nickname: string | null;
  snapshot: {
    block_type: string;
    title: string;
    body: string;
  } | null;
}
