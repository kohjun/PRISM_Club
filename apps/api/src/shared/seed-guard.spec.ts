import {
  assertCliSafe,
  targetHostHint,
} from '../../../../prisma/seed';

describe('seed CLI safety guard', () => {
  describe('targetHostHint', () => {
    test('returns host + db path for a well-formed URL', () => {
      expect(
        targetHostHint(
          'postgresql://prism:prism@localhost:5433/prism_club?schema=public',
        ),
      ).toBe('localhost:5433/prism_club');
    });

    test('redacts credentials by relying on URL.host', () => {
      const out = targetHostHint(
        'postgresql://admin:topsecret@db.example.com:5432/prism_club',
      );
      expect(out).toBe('db.example.com:5432/prism_club');
      expect(out).not.toContain('topsecret');
      expect(out).not.toContain('admin');
    });

    test('handles unset DATABASE_URL', () => {
      expect(targetHostHint(undefined)).toBe('(DATABASE_URL not set)');
    });

    test('handles unparseable DATABASE_URL', () => {
      expect(targetHostHint('not://a]valid[url')).toBe(
        '(unparseable DATABASE_URL)',
      );
    });
  });

  describe('assertCliSafe', () => {
    let exitSpy: jest.SpyInstance;
    let errorSpy: jest.SpyInstance;

    beforeEach(() => {
      // Mock process.exit so the test process doesn't actually die.
      exitSpy = jest
        .spyOn(process, 'exit')
        .mockImplementation(((code?: number) => {
          throw new Error(`__exit:${code ?? 0}__`);
        }) as never);
      errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
    });

    afterEach(() => {
      exitSpy.mockRestore();
      errorSpy.mockRestore();
    });

    test('allows seed when NODE_ENV !== production', () => {
      expect(() => assertCliSafe({ NODE_ENV: 'development' })).not.toThrow();
      expect(() => assertCliSafe({ NODE_ENV: 'test' })).not.toThrow();
      expect(() => assertCliSafe({})).not.toThrow();
    });

    test('refuses with exit code 2 when NODE_ENV=production and no confirmation', () => {
      expect(() =>
        assertCliSafe({ NODE_ENV: 'production' }),
      ).toThrow('__exit:2__');
      expect(errorSpy).toHaveBeenCalled();
      const stderr = errorSpy.mock.calls[0][0] as string;
      expect(stderr).toContain('NODE_ENV=production');
      expect(stderr).toContain('CONFIRM_DESTRUCTIVE_SEED');
    });

    test('allows seed when NODE_ENV=production AND CONFIRM_DESTRUCTIVE_SEED=1', () => {
      expect(() =>
        assertCliSafe({
          NODE_ENV: 'production',
          CONFIRM_DESTRUCTIVE_SEED: '1',
        }),
      ).not.toThrow();
    });

    test('rejects any value other than "1" for the confirmation flag', () => {
      for (const v of ['0', 'true', 'yes', 'on', '']) {
        expect(() =>
          assertCliSafe({
            NODE_ENV: 'production',
            CONFIRM_DESTRUCTIVE_SEED: v,
          }),
        ).toThrow('__exit:2__');
      }
    });

    test('includes the (credential-redacted) DATABASE_URL hint in the error', () => {
      expect(() =>
        assertCliSafe({
          NODE_ENV: 'production',
          DATABASE_URL: 'postgresql://admin:topsecret@db.example.com/prism_club',
        }),
      ).toThrow('__exit:2__');
      const stderr = errorSpy.mock.calls[0][0] as string;
      expect(stderr).toContain('db.example.com');
      expect(stderr).not.toContain('topsecret');
    });
  });
});
