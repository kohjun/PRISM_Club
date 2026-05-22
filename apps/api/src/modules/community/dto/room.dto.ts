/**
 * Shared DTO shapes for rooms and pins.
 *
 * `room_pins.target_id` has no DB FK (target_type discriminates the table),
 * so the server resolves the target rows in a second pass — see RoomService.
 */

export interface EventCardDTO {
  id: string;
  external_event_id: string;
  title: string;
  venue_name: string;
  region: string;
  starts_at: string;
  event_status: string;
  thumbnail_url: string | null;
}

export interface ReferenceDTO {
  id: string;
  type: string;
  url: string;
  title: string;
  source_name: string | null;
  thumbnail_url: string | null;
  summary: string | null;
  status: string;
  /** P2.3 trust tier: OFFICIAL | TRUSTED | COMMUNITY | UNKNOWN. */
  source_tier: string;
}

export interface PinDTO {
  id: string;
  target_type: 'EVENT_CARD' | 'REFERENCE';
  target: EventCardDTO | ReferenceDTO;
  sort_order: number;
}

export interface RoomSummaryDTO {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  origin: 'OFFICIAL' | 'USER';
  room_type: string;
  owner_nickname: string | null;
}

export interface RoomDetailDTO extends RoomSummaryDTO {
  rules: string | null;
  owner: { id: string; nickname: string } | null;
  pins: PinDTO[];
  counts: { post_count: number };
}
