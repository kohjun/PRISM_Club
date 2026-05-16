import { Controller, Get, Param } from '@nestjs/common';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { KnowledgeService } from './knowledge.service';

@Controller()
export class TopicHubController {
  constructor(private readonly knowledge: KnowledgeService) {}

  @Get('categories/:slug/hub')
  async getHub(@Param('slug') slug: string, @CurrentUser() user: RequestUser) {
    return this.knowledge.getHubByCategorySlug(slug, user);
  }
}
