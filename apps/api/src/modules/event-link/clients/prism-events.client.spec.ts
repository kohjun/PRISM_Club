import { PrismEventsClient } from './prism-events.client';

describe('PrismEventsClient', () => {
  const baseUrl = 'http://events.example.com';
  let originalFetch: typeof fetch;
  let envSnapshot: NodeJS.ProcessEnv;

  beforeAll(() => {
    originalFetch = global.fetch;
  });

  beforeEach(() => {
    envSnapshot = { ...process.env };
    process.env.PRISM_EVENTS_API_BASE_URL = baseUrl;
    process.env.PRISM_EVENTS_API_KEY = 'test-key';
    process.env.PRISM_EVENTS_TIMEOUT_MS = '4000';
  });

  afterEach(() => {
    process.env = envSnapshot;
    global.fetch = originalFetch;
  });

  afterAll(() => {
    global.fetch = originalFetch;
  });

  function mockFetch(impl: (url: string, init: RequestInit) => Promise<Response>) {
    global.fetch = jest.fn(impl) as unknown as typeof fetch;
  }

  test('search maps remote items into local ExternalEvent shape', async () => {
    mockFetch(async (url) => {
      expect(url).toContain('/events');
      return new Response(
        JSON.stringify({
          items: [
            {
              id: 'evt-100',
              title: '소개팅 미션 나이트',
              venue: { name: '홍대 스튜디오', region: '서울/홍대' },
              starts_at: '2026-09-01T19:00:00Z',
              status: 'UPCOMING',
              thumbnail_url: 'https://x/y.png',
            },
          ],
        }),
        { status: 200, headers: { 'content-type': 'application/json' } },
      );
    });
    const client = new PrismEventsClient();
    const res = await client.search('소개팅');
    expect(res).toEqual([
      {
        external_event_id: 'evt-100',
        title: '소개팅 미션 나이트',
        venue_name: '홍대 스튜디오',
        region: '서울/홍대',
        starts_at: '2026-09-01T19:00:00Z',
        event_status: 'UPCOMING',
        thumbnail_url: 'https://x/y.png',
      },
    ]);
  });

  test('search returns [] on upstream 5xx', async () => {
    mockFetch(async () => new Response('boom', { status: 502 }));
    const client = new PrismEventsClient();
    const res = await client.search('x');
    expect(res).toEqual([]);
  });

  test('search returns [] on timeout / network error', async () => {
    mockFetch(async () => {
      throw new Error('AbortError: simulated timeout');
    });
    const client = new PrismEventsClient();
    const res = await client.search('x');
    expect(res).toEqual([]);
  });

  test('getById returns null on 404', async () => {
    mockFetch(async () => new Response('not found', { status: 404 }));
    const client = new PrismEventsClient();
    const res = await client.getById('evt-missing');
    expect(res).toBeNull();
  });

  test('getById maps a found event', async () => {
    mockFetch(async () => new Response(
      JSON.stringify({
        id: 'evt-1',
        title: 'X',
        venue: { name: 'V', region: 'R' },
        starts_at: '2026-09-01T19:00:00Z',
        status: 'COMPLETED',
      }),
      { status: 200 },
    ));
    const client = new PrismEventsClient();
    const res = await client.getById('evt-1');
    expect(res?.event_status).toBe('COMPLETED');
    expect(res?.title).toBe('X');
  });

  test('search returns [] when PRISM_EVENTS_API_BASE_URL is unset', async () => {
    delete process.env.PRISM_EVENTS_API_BASE_URL;
    mockFetch(async () => {
      throw new Error('should not be called');
    });
    const client = new PrismEventsClient();
    expect(await client.search('x')).toEqual([]);
    expect(await client.getById('evt-1')).toBeNull();
  });

  test('skips items missing required fields', async () => {
    mockFetch(async () => new Response(
      JSON.stringify({
        items: [
          // valid
          {
            id: 'a',
            title: 'A',
            venue: { name: 'V', region: 'R' },
            starts_at: '2026-01-01T00:00:00Z',
            status: 'UPCOMING',
          },
          // missing starts_at
          { id: 'b', title: 'B', status: 'UPCOMING' },
        ],
      }),
      { status: 200 },
    ));
    const client = new PrismEventsClient();
    const res = await client.search('');
    expect(res.length).toBe(1);
    expect(res[0].external_event_id).toBe('a');
  });

  // --- M20: contract hardening (zod) ----------------------------------

  describe('parseAndNormalize (zod contract)', () => {
    test('accepts a fully-populated event payload', () => {
      const client = new PrismEventsClient();
      const out = client.parseAndNormalize({
        id: 'e1',
        title: 'Full event',
        venue: { name: 'V', region: 'R' },
        starts_at: '2026-06-01T12:00:00Z',
        status: 'UPCOMING',
        thumbnail_url: 'https://x/y.png',
      });
      expect(out).toEqual({
        external_event_id: 'e1',
        title: 'Full event',
        venue_name: 'V',
        region: 'R',
        starts_at: '2026-06-01T12:00:00Z',
        event_status: 'UPCOMING',
        thumbnail_url: 'https://x/y.png',
      });
      expect(client.stats().parsed_ok).toBe(1);
      expect(client.stats().parse_failed).toBe(0);
    });

    test('accepts payload with optional venue + thumbnail omitted; defaults UPCOMING', () => {
      const client = new PrismEventsClient();
      const out = client.parseAndNormalize({
        id: 'e2',
        title: 'Sparse',
        starts_at: '2026-06-01T12:00:00Z',
      });
      expect(out).toEqual({
        external_event_id: 'e2',
        title: 'Sparse',
        venue_name: '',
        region: '',
        starts_at: '2026-06-01T12:00:00Z',
        event_status: 'UPCOMING',
        thumbnail_url: null,
      });
    });

    test('rejects payload missing required id', () => {
      const client = new PrismEventsClient();
      const out = client.parseAndNormalize({
        title: 'No id',
        starts_at: '2026-06-01T12:00:00Z',
      });
      expect(out).toBeNull();
      expect(client.stats().parse_failed).toBe(1);
      expect(client.stats().last_error).not.toBeNull();
    });

    test('rejects payload with empty title', () => {
      const client = new PrismEventsClient();
      const out = client.parseAndNormalize({
        id: 'e3',
        title: '',
        starts_at: '2026-06-01T12:00:00Z',
      });
      expect(out).toBeNull();
      expect(client.stats().parse_failed).toBe(1);
    });

    test('rejects payload with unknown status value', () => {
      const client = new PrismEventsClient();
      const out = client.parseAndNormalize({
        id: 'e4',
        title: 'Bad status',
        starts_at: '2026-06-01T12:00:00Z',
        status: 'WAFFLE',
      });
      expect(out).toBeNull();
      expect(client.stats().parse_failed).toBe(1);
    });

    test('rejects unparseable starts_at', () => {
      const client = new PrismEventsClient();
      const out = client.parseAndNormalize({
        id: 'e5',
        title: 'Bad date',
        starts_at: 'not-a-date',
      });
      expect(out).toBeNull();
      expect(client.stats().last_error).toMatch(/unparseable/);
    });

    test('rejects null / non-object input', () => {
      const client = new PrismEventsClient();
      expect(client.parseAndNormalize(null)).toBeNull();
      expect(client.parseAndNormalize('a string')).toBeNull();
      expect(client.parseAndNormalize(42)).toBeNull();
      expect(client.stats().parse_failed).toBe(3);
    });

    test('thumbnail_url=null is preserved as null', () => {
      const client = new PrismEventsClient();
      const out = client.parseAndNormalize({
        id: 'e6',
        title: 'Null thumb',
        starts_at: '2026-06-01T12:00:00Z',
        thumbnail_url: null,
      });
      expect(out?.thumbnail_url).toBeNull();
    });
  });

  describe('diagnostic() + stats() reflect activity', () => {
    test('records HTTP errors and timeouts into stats', async () => {
      mockFetch(async () => new Response('boom', { status: 502 }));
      const client = new PrismEventsClient();
      await client.search('x');
      const stats = client.stats();
      expect(stats.http_errors).toBe(1);
      expect(stats.last_error).toMatch(/502/);

      mockFetch(async () => {
        const e = new Error('aborted');
        (e as Error & { name: string }).name = 'AbortError';
        throw e;
      });
      await client.search('y');
      expect(client.stats().timeouts).toBe(1);
    });

    test('diagnostic() echoes mode + base_url + cumulative stats', () => {
      const client = new PrismEventsClient();
      const d = client.diagnostic();
      expect(d.mode).toBe('prism');
      expect(d.base_url_configured).toBe(true);
      expect(d.timeout_ms).toBe(4000);
      expect(d.stats.parsed_ok).toBe(0);
    });

    test('diagnostic() reports base_url_configured=false when env missing', () => {
      delete process.env.PRISM_EVENTS_API_BASE_URL;
      const client = new PrismEventsClient();
      expect(client.diagnostic().base_url_configured).toBe(false);
    });
  });
});
