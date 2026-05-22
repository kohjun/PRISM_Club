import { Module } from '@nestjs/common';
import { CommunityModule } from '../community/community.module';
import { ReferenceController } from './reference.controller';
import { ReferenceService } from './reference.service';
import { SourceRulesService } from './source-rules.service';
import { SourceRulesController } from './source-rules.controller';

@Module({
  imports: [CommunityModule],
  controllers: [ReferenceController, SourceRulesController],
  providers: [ReferenceService, SourceRulesService],
  exports: [ReferenceService, SourceRulesService],
})
export class ReferenceModule {}
