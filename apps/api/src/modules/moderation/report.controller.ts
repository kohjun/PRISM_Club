import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { CurrentUser, RequestUser } from '../../shared/decorators/current-user.decorator';
import { ReportService } from './report.service';
import {
  CreateReportInput,
  ResolveReportInput,
} from './dto/moderation.dto';

@Controller()
export class ReportController {
  constructor(private readonly svc: ReportService) {}

  @Post('reports')
  create(
    @CurrentUser() user: RequestUser,
    @Body() body: CreateReportInput,
  ) {
    return this.svc.createReport(body, user);
  }

  @Get('me/reports')
  listMine(@CurrentUser() user: RequestUser) {
    return this.svc.listMine(user.id);
  }

  @Get('admin/reports')
  listQueue(
    @CurrentUser() user: RequestUser,
    @Query('status') status?: string,
  ) {
    return this.svc.listQueue(user, { status });
  }

  @Get('admin/reports/:id')
  getDetail(@CurrentUser() user: RequestUser, @Param('id') id: string) {
    return this.svc.getDetail(id, user);
  }

  /**
   * P6.12 — room-scoped report queue for a room owner or delegated room
   * MODERATOR. Distinct from the global `admin/reports` queue: it only
   * returns OPEN POST/REPLY reports whose target lives in this room, so
   * a room moderator never sees other rooms' reports.
   */
  @Get('rooms/:slug/reports')
  listForRoom(
    @CurrentUser() user: RequestUser,
    @Param('slug') slug: string,
  ) {
    return this.svc.listReportsForRoom(slug, user);
  }

  @Post('admin/reports/:id/resolve')
  resolve(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
    @Body() body: ResolveReportInput,
  ) {
    return this.svc.resolve(id, body, user);
  }

  /**
   * P5.3 bulk resolve. Caps at 50 ids per call; returns a per-id
   * status array plus the shared `batch_id` for audit-log grouping.
   */
  @Post('admin/reports/bulk-resolve')
  bulkResolve(
    @CurrentUser() user: RequestUser,
    @Body()
    body: { report_ids?: string[]; action?: string; note?: string },
  ) {
    return this.svc.bulkResolve(
      body?.report_ids ?? [],
      { action: body?.action ?? '', note: body?.note },
      user,
    );
  }
}
