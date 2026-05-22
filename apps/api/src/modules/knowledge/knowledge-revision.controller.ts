import { Controller, Get, Param, Query } from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { Roles } from '../../shared/decorators/roles.decorator';
import { KnowledgeRevisionService } from './knowledge-revision.service';

@Controller()
export class KnowledgeRevisionController {
  constructor(private readonly svc: KnowledgeRevisionService) {}

  /**
   * Member-facing revision timeline. Honors the space access policy —
   * a PLANNER_ONLY hub stays hidden from regular members (404, not 403,
   * to avoid leaking existence).
   */
  @Get('knowledge-blocks/:blockId/revisions')
  list(
    @Param('blockId') blockId: string,
    @CurrentUser() user: RequestUser,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.svc.listForBlock(blockId, user, {
      cursor,
      limit: limit ? parseInt(limit, 10) : undefined,
    });
  }

  /**
   * Curator/admin variant — same shape, no space gating. Useful when
   * an operator needs to audit cross-space history.
   */
  @Roles('CURATOR', 'MODERATOR', 'ADMIN')
  @Get('admin/knowledge-blocks/:blockId/revisions')
  listForAdmin(
    @Param('blockId') blockId: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.svc.listForBlockAdmin(blockId, {
      cursor,
      limit: limit ? parseInt(limit, 10) : undefined,
    });
  }
}
