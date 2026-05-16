import { Module } from '@nestjs/common';
import { CommunityModule } from '../community/community.module';
import { KnowledgeService } from './knowledge.service';
import { TopicHubController } from './topic-hub.controller';

@Module({
  imports: [CommunityModule],
  providers: [KnowledgeService],
  controllers: [TopicHubController],
  exports: [KnowledgeService],
})
export class KnowledgeModule {}
