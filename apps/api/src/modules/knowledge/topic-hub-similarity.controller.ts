import {
  Controller,
  ForbiddenException,
  Get,
  HttpCode,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { Public } from '../../shared/decorators/public.decorator';
import { TopicHubSimilarityService } from './topic-hub-similarity.service';

@Controller()
export class TopicHubSimilarityController {
  constructor(private readonly svc: TopicHubSimilarityService) {}

  /**
   * P7.1 — `GET /v1/topic-hubs/:slug/similar` returns the top similar
   * hubs for the slug. Public-readable: an anonymous viewer can still
   * see hub→hub edges between PUBLIC hubs, but PLANNER_ONLY edges are
   * filtered out at read time by the service. Empty array means
   * either no similars exist yet (cron hasn't run) or the only
   * candidates are out-of-policy.
   */
  @Public()
  @Get('topic-hubs/:slug/similar')
  async list(
    @Param('slug') slug: string,
    @Query('limit') limit: string | undefined,
    @CurrentUser() viewer: RequestUser | null,
  ) {
    const parsed = limit ? Number(limit) : undefined;
    const cap = Number.isFinite(parsed) && parsed && parsed > 0 ? parsed : 5;
    // CurrentUser may be null for @Public endpoints; collapse to an
    // anonymous viewer with no roles (only PUBLIC accessPolicy will
    // pass `accessPoliciesAllowedFor`).
    const v: { roles: string[] } = viewer ?? { roles: [] };
    return this.svc.listForHubSlug(slug, v, cap);
  }

  /**
   * Admin-only on-demand recompute. Useful right after a backfill of
   * contribution data or a hub-set change so operators don't have to
   * wait for the 03:30 KST cron. Gated by ADMIN role here because
   * full recomputes can hold the advisory lock for several seconds
   * on a many-hub install.
   */
  @Post('admin/recommendations/topic-hub-similarity/recompute')
  @HttpCode(200)
  async recompute(@CurrentUser() viewer: RequestUser) {
    if (!viewer.roles.includes('ADMIN')) {
      throw new ForbiddenException('Admin only');
    }
    return this.svc.recomputeAll();
  }
}
