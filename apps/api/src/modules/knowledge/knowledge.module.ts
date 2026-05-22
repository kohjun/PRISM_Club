import { Module } from '@nestjs/common';
import { CommunityModule } from '../community/community.module';
import { KnowledgeService } from './knowledge.service';
import { TopicHubController } from './topic-hub.controller';
import { KnowledgeContributionService } from './knowledge-contribution.service';
import { KnowledgeContributionController } from './knowledge-contribution.controller';
import { AdminKnowledgeContributionController } from './admin-knowledge-contribution.controller';
import { KnowledgeRevisionService } from './knowledge-revision.service';
import { KnowledgeRevisionController } from './knowledge-revision.controller';
import { ContributionReputationService } from './contribution-reputation.service';
import { ContributionReputationController } from './contribution-reputation.controller';
import { DigestService } from './digest.service';
import { DigestOpsController } from './digest-ops.controller';

@Module({
  imports: [CommunityModule],
  providers: [
    KnowledgeService,
    KnowledgeContributionService,
    KnowledgeRevisionService,
    ContributionReputationService,
    DigestService,
  ],
  controllers: [
    TopicHubController,
    KnowledgeContributionController,
    AdminKnowledgeContributionController,
    KnowledgeRevisionController,
    ContributionReputationController,
    DigestOpsController,
  ],
  exports: [
    KnowledgeService,
    KnowledgeContributionService,
    KnowledgeRevisionService,
    ContributionReputationService,
    DigestService,
  ],
})
export class KnowledgeModule {}
