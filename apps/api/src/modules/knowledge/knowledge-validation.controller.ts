import { Controller, Get, Param } from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { KnowledgeValidationService } from './knowledge-validation.service';

@Controller('knowledge-blocks')
export class KnowledgeValidationController {
  constructor(private readonly svc: KnowledgeValidationService) {}

  /**
   * P7.2 — score + label + signals breakdown. The badge on the
   * knowledge block card calls this lazily so the hub bundle stays
   * lightweight (the bundle uses `scoresForBlocks` for the inlined
   * label-only summary; the bottom sheet hits this for the full
   * breakdown).
   */
  @Get(':blockId/validation')
  async validation(
    @Param('blockId') blockId: string,
    @CurrentUser() viewer: RequestUser,
  ) {
    return this.svc.getFor(blockId, viewer);
  }

  /**
   * P7.2 — chain timeline. Each entry surfaces "누가, 언제, 어떤
   * 컨트리뷰션 통해" so the mobile chain screen can render person-
   * centric history alongside the existing version-centric revision
   * history screen.
   */
  @Get(':blockId/chain')
  async chain(
    @Param('blockId') blockId: string,
    @CurrentUser() viewer: RequestUser,
  ) {
    return this.svc.chainFor(blockId, viewer);
  }
}
