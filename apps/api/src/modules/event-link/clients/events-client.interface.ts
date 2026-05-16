/**
 * External Events/Contenido contract.
 *
 * In milestone 1, the binding is `MockEventsClient` backed by a JSON fixture.
 * When the real Events service ships, swap the provider binding in
 * `event-link.module.ts` without touching callers.
 */

export interface ExternalEvent {
  external_event_id: string;
  title: string;
  venue_name: string;
  region: string;
  starts_at: string; // ISO 8601
  event_status: 'UPCOMING' | 'COMPLETED';
  thumbnail_url: string | null;
}

export interface IEventsClient {
  search(
    q: string,
    opts?: { status?: 'UPCOMING' | 'COMPLETED' },
  ): Promise<ExternalEvent[]>;

  getById(externalEventId: string): Promise<ExternalEvent | null>;
}

export const EVENTS_CLIENT = Symbol('IEventsClient');
