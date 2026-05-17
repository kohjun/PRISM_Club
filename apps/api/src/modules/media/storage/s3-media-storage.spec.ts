import { S3MediaStorage } from './s3-media-storage';

describe('S3MediaStorage', () => {
  let envSnapshot: NodeJS.ProcessEnv;

  beforeEach(() => {
    envSnapshot = { ...process.env };
    // Clear all S3-related env so each test starts from a clean slate.
    for (const k of Object.keys(process.env)) {
      if (k.startsWith('S3_') || k === 'MEDIA_PUBLIC_BASE_URL') {
        delete process.env[k];
      }
    }
  });

  afterEach(() => {
    process.env = envSnapshot;
  });

  test('construction does not throw when env is missing (lazy config)', () => {
    expect(() => new S3MediaStorage()).not.toThrow();
  });

  test('mode() returns "s3(misconfigured)" without S3_BUCKET', () => {
    const storage = new S3MediaStorage();
    expect(storage.mode()).toBe('s3(misconfigured)');
  });

  test('mode() reports bucket name when S3_BUCKET is set', () => {
    process.env.S3_BUCKET = 'my-bucket';
    const storage = new S3MediaStorage();
    expect(storage.mode()).toBe('s3(bucket=my-bucket)');
  });

  test('upload with missing env throws InternalServerErrorException listing missing fields', async () => {
    const storage = new S3MediaStorage();
    await expect(
      storage.upload({
        id: 'x',
        ext: 'png',
        contentType: 'image/png',
        body: Buffer.from([0]),
      }),
    ).rejects.toThrow(/missing env/);
  });

  test('upload builds the right object key and public URL using prefix + public base', async () => {
    process.env.S3_BUCKET = 'prism-club';
    process.env.S3_REGION = 'us-east-1';
    process.env.S3_ACCESS_KEY_ID = 'x';
    process.env.S3_SECRET_ACCESS_KEY = 'y';
    process.env.MEDIA_PUBLIC_BASE_URL = 'https://cdn.example.com/';
    process.env.S3_OBJECT_PREFIX = '/club-media/';

    const storage = new S3MediaStorage();

    // Stub the internal S3Client.send so we don't hit the network.
    const captured: { Bucket?: string; Key?: string; ContentType?: string } = {};
    // @ts-expect-error: reaching into private state for the test
    storage.ensureConfigured();
    // @ts-expect-error: reaching into private state for the test
    storage._client = {
      send: jest.fn(async (cmd: unknown) => {
        const input = (cmd as { input: typeof captured }).input;
        captured.Bucket = input.Bucket;
        captured.Key = input.Key;
        captured.ContentType = input.ContentType;
        return {};
      }),
    };

    const result = await storage.upload({
      id: 'abc-123',
      ext: 'jpg',
      contentType: 'image/jpeg',
      body: Buffer.from([0]),
    });

    expect(captured.Bucket).toBe('prism-club');
    expect(captured.Key).toBe('club-media/abc-123.jpg');
    expect(captured.ContentType).toBe('image/jpeg');
    expect(result.urlPath).toBe('https://cdn.example.com/club-media/abc-123.jpg');
  });
});
