export type RsvpStatus = 'INTERESTED' | 'GOING' | 'ATTENDED';

export interface RsvpDTO {
  id: string;
  event_card_id: string;
  user_id: string;
  status: RsvpStatus;
  created_at: string;
  updated_at: string;
}

export interface RsvpStateDTO {
  my_status: RsvpStatus | null;
  counts: {
    interested: number;
    going: number;
    attended: number;
  };
}

export interface MyRsvpEntryDTO {
  rsvp: RsvpDTO;
  event_card: {
    id: string;
    title: string;
    venue_name: string;
    region: string;
    starts_at: string;
    event_status: string;
    thumbnail_url: string | null;
  };
}

export interface MyRsvpsListDTO {
  items: MyRsvpEntryDTO[];
  next_cursor: string | null;
}
