/**
 * Unified search result shape. Each hit carries a type discriminator, the
 * fields needed to render a list tile (title + snippet), and a small
 * navigation context the client uses to land on the right screen.
 */

export type SearchEntityType =
  | 'topic_hub'
  | 'knowledge_block'
  | 'room'
  | 'post'
  | 'event_card'
  | 'reference';

export const SEARCH_TYPES: SearchEntityType[] = [
  'topic_hub',
  'knowledge_block',
  'room',
  'post',
  'event_card',
  'reference',
];

export interface SearchHitContextTopicHub {
  category_slug: string;
}
export interface SearchHitContextKnowledgeBlock {
  category_slug: string;
  block_type: string;
}
export interface SearchHitContextRoom {
  room_slug: string;
  category_slug: string;
  origin: string;
  owner_nickname: string | null;
}
export interface SearchHitContextPost {
  post_id: string;
  room_slug: string;
  room_name: string;
  author_nickname: string;
}
export interface SearchHitContextEventCard {
  external_event_id: string;
  venue_name: string;
  region: string;
  starts_at: string;
  event_status: string;
}
export interface SearchHitContextReference {
  reference_type: string;
  url: string;
  source_name: string | null;
}

export type SearchHitContext =
  | SearchHitContextTopicHub
  | SearchHitContextKnowledgeBlock
  | SearchHitContextRoom
  | SearchHitContextPost
  | SearchHitContextEventCard
  | SearchHitContextReference;

export interface SearchHitDTO {
  type: SearchEntityType;
  id: string;
  title: string;
  snippet: string;
  context: SearchHitContext;
}

export interface SearchGroupDTO {
  type: SearchEntityType;
  items: SearchHitDTO[];
}

export interface SearchResponseDTO {
  query: string;
  groups: SearchGroupDTO[];
}
