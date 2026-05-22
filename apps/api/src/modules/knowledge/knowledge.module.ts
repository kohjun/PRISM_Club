import { Module } from '@nestjs/common';
import { CommunityModule } from '../community/community.module';
import { KnowledgeService } from './knowledge.service';
import { TopicHubController } from './topic-hub.controller';
import { KnowledgeContributionService } from './knowledge-contribution.service';
import { KnowledgeContributionController } from './knowledge-contribution.controller';
import { AdminKnowledgeContributionController } from './admin-knowledge-contribution.controller';
import { KnowledgeRevisionService } from './knowledge-revision.service';
import { KnowledgeRevisionController } from './knowledge-revision.controller';

@Module({
  imports: [CommunityModule],
  providers: [
    KnowledgeService,
    KnowledgeContributionService,
    KnowledgeRevisionService,
  ],
  controllers: [
    TopicHubController,
    KnowledgeContributionController,
    AdminKnowledgeContributionController,
    KnowledgeRevisionController,
  ],
  exports: [
    KnowledgeService,
    KnowledgeContributionService,
    KnowledgeRevisionService,
  ],
})
export class KnowledgeModule {}
