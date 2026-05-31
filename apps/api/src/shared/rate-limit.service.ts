import {
  Global,
  HttpException,
  HttpStatus,
  Injectable,
  Module,
} from '@nestjs/common';
import { MetricsService } from './metrics.service';
import { TrustScoreService, TrustTier } from './trust-score.service';
import { Viewer } from './access-control.service';

interface RateLimitDecision {
  allowed: boolean;
  current: number;
  limit: number;
  ttl_ms: number;
  reason: 'OK' | 'EXCEEDED' | 'SHADOW';
}

interface ConsumeOpts {
  /** Identifier for the action being throttled, e.g. 'post.create'. */
  scope: string;
  /** Either a viewer (preferred) or an opaque tracker key (IP for anon). */
  viewer?: Viewer & { id: string };
  trackerKey?: string;
  /**
   * Override the tier-derived per-minute limit. Used by higher-abuse
   * scopes (e.g. P6.9 DM) that want a tighter cap than the tier default.
   */
  limitPerMin?: number;
  /**
   * Enforce even when `RATE_LIMIT_ENABLED!=1`. The rest of the app ships
   * rate limiting in shadow mode; DM (P6.9) opts into day-1 enforcement
   * because it is the highest-abuse surface.
   */
  force?: boolean;
}

// Defaults per tier per minute. Override per scope via the service's
// per-scope map if needed.
const TIER_LIMITS_PER_MIN: Record<TrustTier, number> = {
  NEW: 10,
  MEMBER: 60,
  TRUSTED: 180,
  PLANNER: 600,
};

const WINDOW_MS_DEFAULT = 60 * 1000;
const MAX_BUCKET_SIZE = 1_000;

/**
 * P5.1 sliding-window rate limit.
 *
 * Shadow mode (`RATE_LIMIT_ENABLED=0`): always returns `allowed=true`
 * but still records the rate_limit.hit / rate_limit.shadow_hit metric
 * so we can see what *would* have been blocked before enforcing.
 *
 * Enforce mode (`RATE_LIMIT_ENABLED=1`): returns `allowed=false` once
 * the tier-specific limit is exceeded; the caller decides whether to
 * throw 429 or downgrade silently.
 *
 * In-process buckets only — multi-replica deploys see per-instance
 * counters, which is fine for v1 (planners are the only realistic
 * abusers and they're already on PLANNER tier). Redis backend lands
 * once we observe production traffic.
 */
@Injectable()
export class RateLimitService {
  private buckets: Map<string, number[]> = new Map();

  constructor(
    private readonly metrics: MetricsService,
    private readonly trust: TrustScoreService,
  ) {}

  /**
   * Sliding-window consume. Caller is expected to short-circuit
   * its handler when allowed=false.
   */
  consume(opts: ConsumeOpts): RateLimitDecision {
    const enforced =
      opts.force === true || process.env.RATE_LIMIT_ENABLED === '1';
    const tier: TrustTier = opts.viewer
      ? this.trust.syncTierFor(opts.viewer)
      : 'NEW'; // anonymous → tightest tier
    const limit = opts.limitPerMin ?? TIER_LIMITS_PER_MIN[tier];
    const ttlMs = WINDOW_MS_DEFAULT;
    const trackerKey =
      opts.viewer?.id ?? opts.trackerKey ?? 'anonymous';
    const key = `${opts.scope}:${trackerKey}`;

    const now = Date.now();
    let bucket = this.buckets.get(key);
    if (!bucket) {
      bucket = [];
      this.buckets.set(key, bucket);
    }
    // Sliding window: drop entries older than ttlMs
    const cutoff = now - ttlMs;
    while (bucket.length > 0 && bucket[0] < cutoff) bucket.shift();
    // Bound memory in case ttl is very large or limit miscomputed
    if (bucket.length > MAX_BUCKET_SIZE) bucket.shift();

    const current = bucket.length;
    if (current >= limit) {
      this.metrics.inc('rate_limit.hit');
      this.metrics.record(`rate_limit.hit.${opts.scope}`, 1);
      if (!enforced) {
        this.metrics.inc('rate_limit.shadow_hit');
        bucket.push(now);
        return {
          allowed: true,
          current: current + 1,
          limit,
          ttl_ms: ttlMs,
          reason: 'SHADOW',
        };
      }
      return {
        allowed: false,
        current,
        limit,
        ttl_ms: ttlMs,
        reason: 'EXCEEDED',
      };
    }
    bucket.push(now);
    return {
      allowed: true,
      current: current + 1,
      limit,
      ttl_ms: ttlMs,
      reason: 'OK',
    };
  }

  /**
   * consume() + throw the canonical 429 when the limit is exceeded. Keeps
   * the RATE_LIMITED error contract in one place so a throttled write
   * handler stays a single line.
   */
  consumeOrThrow(opts: ConsumeOpts, message = '잠시 후 다시 시도해주세요.'): void {
    const decision = this.consume(opts);
    if (!decision.allowed) {
      throw new HttpException(
        {
          error: {
            code: 'RATE_LIMITED',
            message,
            retry_after_seconds: Math.ceil(decision.ttl_ms / 1000),
          },
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  /** Manual reset — useful in tests and admin "release this user" ops. */
  reset(scope: string, trackerKey: string): void {
    this.buckets.delete(`${scope}:${trackerKey}`);
  }
}

@Global()
@Module({
  providers: [RateLimitService],
  exports: [RateLimitService],
})
export class RateLimitModule {}
