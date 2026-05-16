import { Module } from '@nestjs/common';
import { CommunityModule } from '../community/community.module';
import { KnowledgeService } from './knowledge.service';
import { TopicHubController } from './topic-hub.controller';
import { KnowledgeContributionService } from './knowledge-contribution.service';
import { KnowledgeContributionController } from './knowledge-contribution.controller';
import { AdminKnowledgeContributionController } from './admin-knowledge-contribution.controller';

@Module({
  imports: [CommunityModule],
  providers: [KnowledgeService, KnowledgeContributionService],
  controllers: [
    TopicHubController,
    KnowledgeContributionController,
    AdminKnowledgeContributionController,
  ],
  exports: [KnowledgeService, KnowledgeContributionService],
})
export class KnowledgeModule {}
