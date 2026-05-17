import { Controller, Get } from '@nestjs/common';
import { Public } from '../../shared/decorators/public.decorator';
import { PrismaService } from '../../shared/prisma.service';
import type { BuildMetadata } from './version';
import { readBuildMetadata } from './version';

@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  /// Liveness — always 200 if the process is up. Intentionally minimal:
  /// any caller that wants build metadata should hit `/v1/health/version`
  /// instead.
  @Public()
  @Get()
  check(): { ok: true } {
    return { ok: true };
  }

  /// Readiness — verifies the DB is reachable. Returns 503 when not.
  /// Suitable for k8s readinessProbe / load-balancer health checks.
  @Public()
  @Get('ready')
  async ready(): Promise<{ ok: true; db: 'up' } | never> {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return { ok: true, db: 'up' };
    } catch (e) {
      const err: { ok: false; db: 'down'; error: string } = {
        ok: false,
        db: 'down',
        error: e instanceof Error ? e.message : String(e),
      };
      // Use HTTP 503 via throwing — caught by AllExceptionsFilter.
      const http503 = new Error(JSON.stringify(err));
      (http503 as Error & { status?: number }).status = 503;
      throw http503;
    }
  }

  /// Full build metadata. SAFE TO EXPOSE — derived from env vars set
  /// at boot, no secrets, no DB connection strings, no env dump.
  /// Returns `{ app_version, git_sha, build_time, release_channel,
  /// node_env }` with `'unknown'` defaults when the corresponding env
  /// is not set.
  @Public()
  @Get('version')
  version(): BuildMetadata {
    return readBuildMetadata();
  }
}
