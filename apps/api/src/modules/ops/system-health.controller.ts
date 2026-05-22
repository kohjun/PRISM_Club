import { Controller, Get } from '@nestjs/common';
import { Roles } from '../../shared/decorators/roles.decorator';
import { MetricsService } from '../../shared/metrics.service';

const METRIC_KEYS = [
  'search.latency_ms',
  'search.zero_result',
  'media.upload.success',
  'media.upload.fail',
  'notification.push.sent',
  'notification.push.failed',
  'notification.email.sent',
  'notification.email.failed',
  'rate_limit.hit',
  'events_client.fetch_ms',
  'events_client.error',
] as const;

interface MetricBlockDTO {
  key: string;
  count_1h: number;
  count_24h: number;
  p50_1h: number | null;
  p95_1h: number | null;
  avg_1h: number | null;
}

/**
 * P5.6 system health snapshot.
 *
 * Aggregates the in-memory MetricsService into per-key 1h/24h
 * summaries the admin dashboard renders. Single-process numbers; a
 * multi-replica deploy reports per-instance figures (the operator
 * aggregates mentally). Promoting to Prometheus is a future step.
 */
@Controller()
export class SystemHealthController {
  constructor(private readonly metrics: MetricsService) {}

  @Roles('ADMIN', 'MODERATOR', 'CURATOR')
  @Get('admin/system-health')
  snapshot(): { generated_at: string; metrics: MetricBlockDTO[] } {
    const items: MetricBlockDTO[] = METRIC_KEYS.map((key) => {
      const s = this.metrics.summary(key);
      return {
        key,
        count_1h: s.count_1h,
        count_24h: s.count_24h,
        p50_1h: s.p50_1h,
        p95_1h: s.p95_1h,
        avg_1h: s.avg_1h,
      };
    });
    // Also surface any *other* keys that have been recorded but aren't
    // in the curated list (helps when a new feature lands a counter
    // before the curated list is updated).
    const seen = new Set(METRIC_KEYS);
    for (const k of this.metrics.keys()) {
      if (!seen.has(k as (typeof METRIC_KEYS)[number])) {
        const s = this.metrics.summary(k);
        items.push({
          key: k,
          count_1h: s.count_1h,
          count_24h: s.count_24h,
          p50_1h: s.p50_1h,
          p95_1h: s.p95_1h,
          avg_1h: s.avg_1h,
        });
      }
    }
    return { generated_at: new Date().toISOString(), metrics: items };
  }
}
