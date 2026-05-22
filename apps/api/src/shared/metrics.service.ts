import { Global, Injectable, Module } from '@nestjs/common';

const MAX_SAMPLES_PER_KEY = 10_000;
const WINDOW_1H_MS = 60 * 60 * 1000;
const WINDOW_24H_MS = 24 * 60 * 60 * 1000;

interface Sample {
  t: number; // ms since epoch
  v: number;
}

/**
 * P5.6 in-memory metrics ring.
 *
 * Each `key` gets a FIFO buffer capped at 10k timestamped samples.
 * Callers `record(key, value)` (latency ms, byte count, success/fail
 * 1/0); the system-health controller asks for `summary(key)` which
 * returns count + p50 + p95 + average over a 1h and 24h window.
 *
 * Single-process only — multi-replica deployments see per-instance
 * numbers, which is fine for the v1 health page (the operator
 * mentally aggregates). Promoting to Prometheus is a future step
 * once we have multi-replica traffic to measure.
 */
@Injectable()
export class MetricsService {
  private buffers: Map<string, Sample[]> = new Map();

  record(key: string, value: number): void {
    const now = Date.now();
    let buf = this.buffers.get(key);
    if (!buf) {
      buf = [];
      this.buffers.set(key, buf);
    }
    buf.push({ t: now, v: value });
    if (buf.length > MAX_SAMPLES_PER_KEY) {
      buf.splice(0, buf.length - MAX_SAMPLES_PER_KEY);
    }
  }

  /** Increment a counter — convenience wrapper that records value=1. */
  inc(key: string): void {
    this.record(key, 1);
  }

  summary(key: string): {
    count_1h: number;
    count_24h: number;
    p50_1h: number | null;
    p95_1h: number | null;
    avg_1h: number | null;
  } {
    const buf = this.buffers.get(key) ?? [];
    const now = Date.now();
    const cutoff1h = now - WINDOW_1H_MS;
    const cutoff24h = now - WINDOW_24H_MS;
    const last1h = buf.filter((s) => s.t >= cutoff1h);
    const last24h = buf.filter((s) => s.t >= cutoff24h);
    const sorted = [...last1h].map((s) => s.v).sort((a, b) => a - b);
    return {
      count_1h: last1h.length,
      count_24h: last24h.length,
      p50_1h: percentile(sorted, 0.5),
      p95_1h: percentile(sorted, 0.95),
      avg_1h:
        last1h.length > 0
          ? last1h.reduce((sum, s) => sum + s.v, 0) / last1h.length
          : null,
    };
  }

  keys(): string[] {
    return [...this.buffers.keys()];
  }
}

function percentile(sortedValues: number[], q: number): number | null {
  if (sortedValues.length === 0) return null;
  const idx = Math.min(
    sortedValues.length - 1,
    Math.floor(sortedValues.length * q),
  );
  return sortedValues[idx];
}

/**
 * Global so feature modules (search / media / notification / rate
 * limiter) can record without importing a module each time.
 */
@Global()
@Module({
  providers: [MetricsService],
  exports: [MetricsService],
})
export class MetricsModule {}
