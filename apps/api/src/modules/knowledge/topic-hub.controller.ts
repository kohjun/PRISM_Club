import { Controller, Get, Param } from '@nestjs/common';
import { KnowledgeService } from './knowledge.service';

@Controller()
export class TopicHubController {
  constructor(private readonly knowledge: KnowledgeService) {}

  @Get('categories/:slug/hub')
  async getHub(@Param('slug') slug: string) {
    return this.knowledge.getHubByCategorySlug(slug);
  }
}
