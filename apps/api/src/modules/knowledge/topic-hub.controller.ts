import { Controller, Get, Param, Query } from '@nestjs/common';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { KnowledgeService } from './knowledge.service';
import { DigestService } from './digest.service';

@Controller()
export class TopicHubController {
  constructor(
    private readonly knowledge: KnowledgeService,
    private readonly digest: DigestService,
  ) {}

  @Get('categories/:slug/hub')
  async getHub(@Param('slug') slug: string, @CurrentUser() user: RequestUser) {
    return this.knowledge.getHubByCategorySlug(slug, user);
  }

  /**
   * P2.4 weekly digest. `period=current|previous` (default current).
   * Returns null when no digest has been generated for the period —
   * empty weeks intentionally skip persistence.
   */
  @Get('categories/:slug/digest')
  async getDigest(
    @Param('slug') slug: string,
    @CurrentUser() user: RequestUser,
    @Query('period') periodRaw?: string,
  ) {
    const period = periodRaw === 'previous' ? 'previous' : 'current';
    return this.digest.getForCategory(slug, user, period);
  }
}
