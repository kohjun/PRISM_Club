import { HttpException } from '@nestjs/common';
import { RateLimitService } from './rate-limit.service';
import { MetricsService } from './metrics.service';
import { TrustScoreService, TrustTier } from './trust-score.service';
import { Viewer } from './access-control.service';

// RateLimitService only calls metrics.inc/record and trust.syncTierFor,
// so trivial stubs are enough — no Nest DI / DB needed.
function makeService(tier: TrustTier = 'MEMBER'): RateLimitService {
  const metrics = {
    inc: () => undefined,
    record: () => undefined,
  } as unknown as MetricsService;
  const trust = {
    syncTierFor: () => tier,
  } as unknown as TrustScoreService;
  return new RateLimitService(metrics, trust);
}

const viewer = { id: 'u1', roles: ['MEMBER'] } as Viewer & { id: string };

describe('RateLimitService', () => {
  const original = process.env.RATE_LIMIT_ENABLED;
  afterEach(() => {
    if (original === undefined) delete process.env.RATE_LIMIT_ENABLED;
    else process.env.RATE_LIMIT_ENABLED = original;
  });

  it('shadow mode (RATE_LIMIT_ENABLED unset): allows past the limit but flags SHADOW', () => {
    delete process.env.RATE_LIMIT_ENABLED;
    const svc = makeService();
    let last = svc.consume({ scope: 's', viewer, limitPerMin: 3 });
    for (let i = 0; i < 10; i++) {
      last = svc.consume({ scope: 's', viewer, limitPerMin: 3 });
    }
    expect(last.allowed).toBe(true);
    expect(last.reason).toBe('SHADOW');
  });

  it('enforce mode (=1): blocks once the limit is exceeded', () => {
    process.env.RATE_LIMIT_ENABLED = '1';
    const svc = makeService();
    const results = Array.from({ length: 5 }, () =>
      svc.consume({ scope: 's', viewer, limitPerMin: 3 }),
    );
    expect(results.slice(0, 3).every((r) => r.allowed)).toBe(true);
    expect(results[3].allowed).toBe(false);
    expect(results[3].reason).toBe('EXCEEDED');
  });

  it('force: enforces even when RATE_LIMIT_ENABLED is not 1 (the DM path)', () => {
    delete process.env.RATE_LIMIT_ENABLED;
    const svc = makeService();
    let last = svc.consume({ scope: 'dm', viewer, limitPerMin: 2, force: true });
    for (let i = 0; i < 4; i++) {
      last = svc.consume({ scope: 'dm', viewer, limitPerMin: 2, force: true });
    }
    expect(last.allowed).toBe(false);
    expect(last.reason).toBe('EXCEEDED');
  });

  it('limitPerMin overrides the tier default', () => {
    process.env.RATE_LIMIT_ENABLED = '1';
    const svc = makeService('PLANNER'); // tier default is 600
    const results = Array.from({ length: 3 }, () =>
      svc.consume({ scope: 'o', viewer, limitPerMin: 1 }),
    );
    expect(results[0].allowed).toBe(true);
    expect(results[0].limit).toBe(1);
    expect(results[1].allowed).toBe(false);
  });

  it('consumeOrThrow throws a 429 HttpException once exceeded (force)', () => {
    delete process.env.RATE_LIMIT_ENABLED;
    const svc = makeService();
    expect(() => {
      for (let i = 0; i < 5; i++) {
        svc.consumeOrThrow({ scope: 'd2', viewer, limitPerMin: 2, force: true });
      }
    }).toThrow(HttpException);
  });

  it('consumeOrThrow does not throw within the limit', () => {
    process.env.RATE_LIMIT_ENABLED = '1';
    const svc = makeService();
    expect(() =>
      svc.consumeOrThrow({ scope: 's2', viewer, limitPerMin: 5 }),
    ).not.toThrow();
  });
});
