import {
  Controller,
  Get,
  Header,
  Query,
  Res,
} from '@nestjs/common';
import { Response } from 'express';
import { Roles } from '../../shared/decorators/roles.decorator';
import { AuditLogService } from './audit-log.service';

const CSV_HARD_CAP = 10_000;

@Controller()
export class AuditLogController {
  constructor(private readonly svc: AuditLogService) {}

  @Roles('ADMIN', 'MODERATOR', 'CURATOR')
  @Get('admin/audit-log')
  list(
    @Query('actor_id') actorId?: string,
    @Query('target_type') targetType?: string,
    @Query('target_id') targetId?: string,
    @Query('action') action?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.svc.list({
      actorId,
      targetType,
      targetId,
      action,
      from: from ? new Date(from) : undefined,
      to: to ? new Date(to) : undefined,
      cursor,
      limit: limit ? parseInt(limit, 10) : undefined,
    });
  }

  /**
   * Bounded CSV export. Caller is expected to narrow with from/to;
   * we still hard-cap at 10k rows to bound connection time.
   */
  @Roles('ADMIN', 'MODERATOR', 'CURATOR')
  @Get('admin/audit-log.csv')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header(
    'Content-Disposition',
    'attachment; filename="audit-log.csv"',
  )
  async csv(
    @Res({ passthrough: true }) res: Response,
    @Query('actor_id') actorId?: string,
    @Query('target_type') targetType?: string,
    @Query('target_id') targetId?: string,
    @Query('action') action?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ): Promise<string> {
    const rows = await this.svc.listCsv({
      actorId,
      targetType,
      targetId,
      action,
      from: from ? new Date(from) : undefined,
      to: to ? new Date(to) : undefined,
      hardCap: CSV_HARD_CAP,
    });
    const header = [
      'occurred_at',
      'source',
      'action',
      'actor_id',
      'actor_nickname',
      'target_type',
      'target_id',
      'note',
    ].join(',');
    const lines = rows.map((r) =>
      [
        r.occurred_at,
        r.source,
        r.action,
        r.actor.id ?? '',
        csvEscape(r.actor.nickname ?? ''),
        r.target_type ?? '',
        r.target_id ?? '',
        csvEscape(r.note ?? ''),
      ].join(','),
    );
    return [header, ...lines].join('\n') + '\n';
  }
}

function csvEscape(s: string): string {
  if (s.includes(',') || s.includes('"') || s.includes('\n')) {
    return '"' + s.replaceAll('"', '""') + '"';
  }
  return s;
}
