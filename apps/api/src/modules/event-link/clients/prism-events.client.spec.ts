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
});
