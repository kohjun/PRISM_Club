import { Injectable, Logger } from '@nestjs/common';
import { ExternalEvent, IEventsClient } from './events-client.interface';

/**
 * Real PRISM EVENT / CONTENIDO client.
 *
 * Activated when `EVENTS_CLIENT_MODE=prism`. Hits a configurable HTTP API
 * via `fetch` (Node 20+), normalizes responses into the local
 * `ExternalEvent` shape, and degrades gracefully on timeout / 4xx / 5xx
 * so the Club surfaces never explode when upstream is down.
 *
 * Expected upstream contract (subject to negotiation when CONTENIDO ships):
 *   GET  {BASE}/events?q=<query>&status=UPCOMING|COMPLETED
 *     → 200 { items: PrismEventDTO[] }
 *   GET  {BASE}/events/:externalEventId
 *     → 200 PrismEventDTO   | 404 not found
 *
 *   PrismEventDTO = {
 *     id: string;          // external_event_id
 *     title: string;
 *     venue: { name: string; region: string };
 *     starts_at: string;   // ISO 8601
 *     status: 'UPCOMING' | 'COMPLETED';
 *     thumbnail_url?: string | null;
 *   }
 */
@Injectable()
export class PrismEventsClient implements IEventsClient {
  private readonly log = new Logger(PrismEventsClient.name);

  private readonly baseUrl =
    process.env.PRISM_EVENTS_API_BASE_URL?.replace(/\/+$/, '') ?? '';
  private readonly apiKey = process.env.PRISM_EVENTS_API_KEY ?? '';
  private readonly timeoutMs = Number(
    process.env.PRISM_EVENTS_TIMEOUT_MS ?? 4000,
  );

  async search(
    q: string,
    opts?: { status?: 'UPCOMING' | 'COMPLETED' },
  ): Promise<ExternalEvent[]> {
    if (!this.baseUrl) {
      this.log.warn(
        'PRISM_EVENTS_API_BASE_URL not set; falling back to empty result set',
      );
      return [];
    }

    const url = new URL(`${this.baseUrl}/events`);
    if (q.trim().length > 0) url.searchParams.set('q', q.trim());
    if (opts?.status) url.searchParams.set('status', opts.status);

    try {
      const res = await this.fetchWithTimeout(url.toString(), 'GET');
      if (!res.ok) {
        this.log.warn(
          `PRISM events search returned HTTP ${res.status}; returning []`,
        );
        return [];
      }
      const body = (await res.json()) as { items?: PrismEventDTO[] } | null;
      const items = body?.items ?? [];
      return items
        .map((it) => this.normalize(it))
        .filter((e): e is ExternalEvent => e !== null);
    } catch (e) {
      this.log.warn(
        `PRISM events search failed (${e instanceof Error ? e.message : String(e)}); returning []`,
      );
      return [];
    }
  }

  async getById(externalEventId: string): Promise<ExternalEvent | null> {
    if (!this.baseUrl) {
      return null;
    }
    if (!externalEventId) return null;

    const url = `${this.baseUrl}/events/${encodeURIComponent(externalEventId)}`;
    try {
      const res = await this.fetchWithTimeout(url, 'GET');
      if (res.status === 404) return null;
      if (!res.ok) {
        this.log.warn(`PRISM events getById HTTP ${res.status}`);
        return null;
      }
      const body = (await res.json()) as PrismEventDTO | null;
      return body ? this.normalize(body) : null;
    } catch (e) {
      this.log.warn(
        `PRISM events getById failed (${e instanceof Error ? e.message : String(e)})`,
      );
      return null;
    }
  }

  private async fetchWithTimeout(url: string, method: 'GET'): Promise<Response> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const headers: Record<string, string> = {
        Accept: 'application/json',
      };
      if (this.apiKey) headers['Authorization'] = `Bearer ${this.apiKey}`;
      const res = await fetch(url, {
        method,
        headers,
        signal: controller.signal,
      });
      return res;
    } finally {
      clearTimeout(timer);
    }
  }

  /// Map a remote PrismEventDTO to the local ExternalEvent shape. Returns
  /// null when the remote payload is missing required fields (we keep
  /// search resilient by skipping bad rows instead of throwing).
  private normalize(input: PrismEventDTO): ExternalEvent | null {
    if (!input || typeof input !== 'object') return null;
    if (!input.id || !input.title || !input.starts_at) return null;
    const status = input.status === 'COMPLETED' ? 'COMPLETED' : 'UPCOMING';
    return {
      external_event_id: input.id,
      title: input.title,
      venue_name: input.venue?.name ?? '',
      region: input.venue?.region ?? '',
      starts_at: input.starts_at,
      event_status: status,
      thumbnail_url: input.thumbnail_url ?? null,
    };
  }
}

interface PrismEventDTO {
  id: string;
  title: string;
  venue?: { name?: string; region?: string };
  starts_at: string;
  status: 'UPCOMING' | 'COMPLETED';
  thumbnail_url?: string | null;
}
