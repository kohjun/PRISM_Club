import { Injectable } from '@nestjs/common';
import { ExternalEvent, IEventsClient } from './events-client.interface';
import fixtures from './mock-events.fixtures.json';

/**
 * Mock implementation of IEventsClient.
 *
 * Backed by a static JSON fixture. Adds a small artificial latency so the
 * mobile picker's loading states are visible during development.
 */
@Injectable()
export class MockEventsClient implements IEventsClient {
  private readonly events: ExternalEvent[] = fixtures as ExternalEvent[];

  async search(
    q: string,
    opts?: { status?: 'UPCOMING' | 'COMPLETED' },
  ): Promise<ExternalEvent[]> {
    await this.simulateLatency();

    const needle = q.trim().toLowerCase();
    let matches = needle.length === 0
      ? this.events
      : this.events.filter(
          (e) =>
            e.title.toLowerCase().includes(needle) ||
            e.venue_name.toLowerCase().includes(needle) ||
            e.region.toLowerCase().includes(needle),
        );

    if (opts?.status) {
      matches = matches.filter((e) => e.event_status === opts.status);
    }

    return matches;
  }

  async getById(externalEventId: string): Promise<ExternalEvent | null> {
    await this.simulateLatency();
    return this.events.find((e) => e.external_event_id === externalEventId) ?? null;
  }

  private simulateLatency(): Promise<void> {
    const ms = 80 + Math.floor(Math.random() * 70); // 80–149ms
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
