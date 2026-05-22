import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import {
  CurrentUser,
  RequestUser,
} from '../../shared/decorators/current-user.decorator';
import { Roles } from '../../shared/decorators/roles.decorator';
import { SourceRulesService } from './source-rules.service';

interface CreateRuleBody {
  domain_pattern?: string;
  tier?: string;
  note?: string | null;
}

interface PatchRuleBody {
  tier?: string;
  note?: string | null;
}

@Controller()
export class SourceRulesController {
  constructor(private readonly svc: SourceRulesService) {}

  @Roles('CURATOR', 'MODERATOR', 'ADMIN')
  @Get('admin/reference-source-rules')
  list() {
    return this.svc.listRules();
  }

  @Roles('CURATOR', 'MODERATOR', 'ADMIN')
  @Post('admin/reference-source-rules')
  @HttpCode(200)
  create(
    @Body() body: CreateRuleBody,
    @CurrentUser() user: RequestUser,
  ) {
    return this.svc.createRule(
      {
        domain_pattern: body?.domain_pattern ?? '',
        tier: body?.tier ?? 'UNKNOWN',
        note: body?.note ?? null,
      },
      user.id,
    );
  }

  @Roles('CURATOR', 'MODERATOR', 'ADMIN')
  @Patch('admin/reference-source-rules/:id')
  @HttpCode(200)
  patch(@Param('id') id: string, @Body() body: PatchRuleBody) {
    return this.svc.patchRule(id, body ?? {});
  }

  @Roles('CURATOR', 'MODERATOR', 'ADMIN')
  @Delete('admin/reference-source-rules/:id')
  @HttpCode(200)
  delete(@Param('id') id: string) {
    return this.svc.deleteRule(id);
  }

  /**
   * Re-tier a single reference (used after a rule change to refresh
   * an obvious miscategorisation).
   */
  @Roles('CURATOR', 'MODERATOR', 'ADMIN')
  @Post('admin/references/:id/retier')
  @HttpCode(200)
  retier(@Param('id') id: string) {
    return this.svc.retierReference(id);
  }

  /** Full re-tier — bulk catch-up after seed/rule changes. */
  @Roles('ADMIN')
  @Post('ops/references/retier-all')
  @HttpCode(200)
  retierAll() {
    return this.svc.retierAll();
  }
}
