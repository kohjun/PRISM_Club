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

  @Post('admin/reports/:id/resolve')
  resolve(
    @CurrentUser() user: RequestUser,
    @Param('id') id: string,
    @Body() body: ResolveReportInput,
  ) {
    return this.svc.resolve(id, body, user);
  }
}
