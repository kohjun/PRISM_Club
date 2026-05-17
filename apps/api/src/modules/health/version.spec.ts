import { readBuildMetadata } from './version';

describe('readBuildMetadata', () => {
  const ORIGINAL_ENV = { ...process.env };

  beforeEach(() => {
    // Wipe the metadata-relevant envs so each test starts from a clean
    // slate and the defaults branch is reachable.
    delete process.env.APP_VERSION;
    delete process.env.GIT_SHA;
    delete process.env.BUILD_TIME;
    delete process.env.RELEASE_CHANNEL;
    // NODE_ENV is set by Jest; restore from ORIGINAL_ENV per test below.
  });

  afterAll(() => {
    process.env = ORIGINAL_ENV;
  });

  test('returns "unknown" defaults when no envs are set', () => {
    process.env.NODE_ENV = 'development';
    const meta = readBuildMetadata();
    expect(meta).toEqual({
      app_version: 'unknown',
      git_sha: 'unknown',
      build_time: null,
      release_channel: 'unknown',
      node_env: 'development',
    });
  });

  test('reads APP_VERSION, GIT_SHA, BUILD_TIME, RELEASE_CHANNEL from env', () => {
    process.env.APP_VERSION = '0.1.0-beta.1';
    process.env.GIT_SHA = 'a14ba85';
    process.env.BUILD_TIME = '2026-05-17T22:00:00Z';
    process.env.RELEASE_CHANNEL = 'staging';
    process.env.NODE_ENV = 'production';

    expect(readBuildMetadata()).toEqual({
      app_version: '0.1.0-beta.1',
      git_sha: 'a14ba85',
      build_time: '2026-05-17T22:00:00.000Z',
      release_channel: 'staging',
      node_env: 'production',
    });
  });

  test('lowercases and validates RELEASE_CHANNEL; unknown values become "unknown"', () => {
    process.env.RELEASE_CHANNEL = 'STAGING';
    expect(readBuildMetadata().release_channel).toBe('staging');

    process.env.RELEASE_CHANNEL = 'qa';
    expect(readBuildMetadata().release_channel).toBe('unknown');

    process.env.RELEASE_CHANNEL = '';
    expect(readBuildMetadata().release_channel).toBe('unknown');
  });

  test('normalizes BUILD_TIME to ISO when parseable; passes through unparseable raw', () => {
    process.env.BUILD_TIME = '2026-01-02 03:04:05 UTC';
    expect(readBuildMetadata().build_time).toBe('2026-01-02T03:04:05.000Z');

    process.env.BUILD_TIME = 'not-a-date';
    expect(readBuildMetadata().build_time).toBe('not-a-date');

    process.env.BUILD_TIME = '';
    expect(readBuildMetadata().build_time).toBeNull();
  });

  test('whitespace in env values is trimmed', () => {
    process.env.APP_VERSION = '  0.1.0  ';
    process.env.GIT_SHA = '   abcdef0   ';
    process.env.RELEASE_CHANNEL = '   BETA  ';
    const meta = readBuildMetadata();
    expect(meta.app_version).toBe('0.1.0');
    expect(meta.git_sha).toBe('abcdef0');
    expect(meta.release_channel).toBe('beta');
  });

  test('never includes any other env-derived field', () => {
    process.env.APP_VERSION = '0.1.0';
    process.env.JWT_SECRET = 'should-never-leak';
    process.env.DATABASE_URL = 'postgresql://should-never-leak';
    const meta = readBuildMetadata();
    expect(Object.keys(meta).sort()).toEqual(
      [
        'app_version',
        'build_time',
        'git_sha',
        'node_env',
        'release_channel',
      ].sort(),
    );
    expect(JSON.stringify(meta)).not.toContain('should-never-leak');
  });
});
