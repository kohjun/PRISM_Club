// P6.9 — Scoped DM DTOs.

export type DmScope = 'RECRUITMENT' | 'CONTRIBUTION';

export interface CreateDmChannelInput {
  scope: string;
  ref_id: string;
  /**
   * Required only when the caller is the party_b side of a RECRUITMENT
   * channel (the post author opening a thread with a specific
   * applicant). For the applicant side, and for both CONTRIBUTION
   * sides, the counterpart is derived from the workflow.
   */
  counterpart_id?: string;
}

export interface SendDmMessageInput {
  body: string;
}

export interface DmCounterpartDTO {
  id: string;
  nickname: string | null;
}

export interface DmChannelDTO {
  id: string;
  scope: string;
  ref_id: string;
  counterpart: DmCounterpartDTO;
  status: string; // OPEN | CLOSED
  last_message_at: string | null;
  unread: boolean;
  created_at: string;
}

export interface DmChannelListDTO {
  items: DmChannelDTO[];
}

export interface DmMessageDTO {
  id: string;
  channel_id: string;
  sender_id: string;
  body: string;
  status: string; // VISIBLE | HIDDEN
  mine: boolean;
  created_at: string;
}

export interface DmMessageListDTO {
  items: DmMessageDTO[];
  next_cursor: string | null;
  channel_status: string;
}
