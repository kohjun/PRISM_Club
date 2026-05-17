import { Injectable, Logger } from '@nestjs/common';
import { z } from 'zod';
import { ExternalEvent, IEventsClient } from './events-client.interface';

/**
 * Real PRISM EVENT / CONTENIDO client.
 *
 * Activated when `EVENTS_CLIENT_MODE=prism`. Hits a configurable HTTP API
 * via `fetch` (Node 20+), validates responses with zod, normalizes them
 * into the local `ExternalEvent` shape, and degrades gracefully on
 * timeout / 4xx / 5xx so the Club surfaces never explode when upstream
 * is down.
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
 *     venue?: { name?: string; region?: string };
 *     starts_at: string;   // ISO 8601
 *     status?: 'UPCOMING' | 'COMPLETED';
 *     thumbnail_url?: string | null;
 *   }
 *
 * Skipped rows (zod parse failures, missing required fields, malformed
 * timestamps) are counted in `stats()` so operators can see contract
 * drift from the admin diagnostic endpoint.
 */

const PrismVenueSchema = z
  .object({
    name: z.string().optional(),
    region: z.string().optional(),
  })
  .partial();

export const PrismEventDTOSchema = z.object({
  id: z.string().min(1),
  title: z.string().min(1),
  starts_at: z.string().min(1),
  venue: PrismVenueSchema.optional(),
  status: z.enum(['UPCOMING', 'COMPLETED']).optional(),
  thumbnail_url: z.string().nullable().optional(),
});

export const PrismEventListEnvelopeSchema = z.object({
  items: z.array(z.unknown()).optional(),
});

export type PrismEventDTO = z.infer<typeof PrismEventDTOSchema>;

export interface PrismEventsClientStats {
  parsed_ok: number;
  parse_failed: number;
  http_errors: number;
  timeouts: number;
  last_error: string | null;
  last_error_at: string | null;
}

@Injectable()
export class PrismEventsClient implements IEventsClient {
  private readonly log = new Logger(PrismEventsClient.name);

  private readonly baseUrl =
    process.env.PRISM_EVENTS_API_BASE_URL?.replace(/\/+$/, '') ?? '';
  private readonly apiKey = process.env.PRISM_EVENTS_API_KEY ?? '';
  private readonly timeoutMs = Number(
    process.env.PRISM_EVENTS_TIMEOUT_MS ?? 4000,
  );

  private statsState: PrismEventsClientStats = {
    parsed_ok: 0,
    parse_failed: 0,
    http_errors: 0,
    timeouts: 0,
    last_error: null,
    last_error_at: null,
  };

  /** Read-only snapshot of cumulative parse / HTTP outcomes. */
  stats(): PrismEventsClientStats {
    return { ...this.statsState };
  }

  /**
   * Public entry: PRISM events client mode label + base URL + cumulative
   * stats. Surfaced via the admin diagnostic endpoint.
   */
  diagnostic(): {
    mode: 'prism';
    base_url_configured: boolean;
    timeout_ms: number;
    stats: PrismEventsClientStats;
  } {
    return {
      mode: 'prism',
      base_url_configured: this.baseUrl.length > 0,
      timeout_ms: this.timeoutMs,
      stats: this.stats(),
    };
  }

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
        this.recordHttpError(res.status, `search HTTP ${res.status}`);
        this.log.warn(
          `PRISM events search returned HTTP ${res.status}; returning []`,
        );
        return [];
      }
      const raw = (await res.json()) as unknown;
      const envelope = PrismEventListEnvelopeSchema.safeParse(raw);
      if (!envelope.success) {
        this.recordParseFailure(envelope.error.message);
        this.log.warn(
          `PRISM events search envelope malformed: ${envelope.error.message}; returning []`,
        );
        return [];
      }
      const items = envelope.data.items ?? [];
      const out: ExternalEvent[] = [];
      for (const it of items) {
        const normalized = this.parseAndNormalize(it);
        if (normalized) out.push(normalized);
      }
      return out;
    } catch (e) {
      this.recordTimeoutOrThrow(e);
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
        this.recordHttpError(res.status, `getById HTTP ${res.status}`);
        this.log.warn(`PRISM events getById HTTP ${res.status}`);
        return null;
      }
      const raw = (await res.json()) as unknown;
      return this.parseAndNormalize(raw);
    } catch (e) {
      this.recordTimeoutOrThrow(e);
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

  /**
   * Validate a single raw row against the contract and convert to the
   * local ExternalEvent shape. Increments parse counters as a side
   * effect. Returns null on validation failure or unparseable date.
   */
  parseAndNormalize(raw: unknown): ExternalEvent | null {
    const parsed = PrismEventDTOSchema.safeParse(raw);
    if (!parsed.success) {
      this.recordParseFailure(parsed.error.issues[0]?.message ?? 'invalid');
      return null;
    }
    const dto = parsed.data;
    // Validate starts_at parses as a real date — zod only checks string-ness.
    if (Number.isNaN(Date.parse(dto.starts_at))) {
      this.recordParseFailure(`unparseable starts_at: ${dto.starts_at}`);
      return null;
    }
    this.statsState.parsed_ok += 1;
    const status: 'UPCOMING' | 'COMPLETED' =
      dto.status === 'COMPLETED' ? 'COMPLETED' : 'UPCOMING';
    return {
      external_event_id: dto.id,
      title: dto.title,
      venue_name: dto.venue?.name ?? '',
      region: dto.venue?.region ?? '',
      starts_at: dto.starts_at,
      event_status: status,
      thumbnail_url: dto.thumbnail_url ?? null,
    };
  }

  private recordParseFailure(message: string): void {
    this.statsState.parse_failed += 1;
    this.statsState.last_error = message;
    this.statsState.last_error_at = new Date().toISOString();
  }

  private recordHttpError(status: number, message: string): void {
    this.statsState.http_errors += 1;
    this.statsState.last_error = `${message} (status=${status})`;
    this.statsState.last_error_at = new Date().toISOString();
  }

  private recordTimeoutOrThrow(e: unknown): void {
    const msg = e instanceof Error ? e.message : String(e);
    const isTimeout =
      e instanceof Error && (e.name === 'AbortError' || /timeout/i.test(msg));
    if (isTimeout) {
      this.statsState.timeouts += 1;
    } else {
      this.statsState.http_errors += 1;
    }
    this.statsState.last_error = msg;
    this.statsState.last_error_at = new Date().toISOString();
  }
}
