import {
  Controller,
  Get,
  Header,
  HttpCode,
  Post,
  Query,
  Res,
} from '@nestjs/common';
import { Response } from 'express';
import { PrismaService } from '../../shared/prisma.service';
import { Roles } from '../../shared/decorators/roles.decorator';
import { AnalyticsRetentionCron } from './analytics-retention.cron';

const CSV_HARD_CAP = 10_000;

@Controller()
export class AnalyticsOpsController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly retention: AnalyticsRetentionCron,
  ) {}

  /**
   * Manual retention prune — runs the same body as the daily cron.
   * Used to catch up after a deploy hop or to verify the path in
   * staging without waiting 24h.
   */
  @Roles('ADMIN')
  @Post('admin/analytics/retention/run')
  @HttpCode(200)
  runRetention() {
    return this.retention.run();
  }

  /** Daily-bucket counts per event_type for the requested window. */
  @Roles('ADMIN', 'MODERATOR', 'CURATOR')
  @Get('admin/analytics/daily-counts')
  async dailyCounts(
    @Query('event_type') eventType?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ): Promise<{ event_type: string; day: string; count: number }[]> {
    const fromDate = from
      ? new Date(from)
      : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const toDate = to ? new Date(to) : new Date();
    // Raw SQL because Prisma's groupBy can't aggregate by date_trunc.
    const rows = (await this.prisma.$queryRaw<
      { event_type: string; day: Date; count: bigint }[]
    >`
      SELECT
        "event_type",
        date_trunc('day', "created_at") AS day,
        COUNT(*)::bigint AS count
      FROM "analytics_events"
      WHERE "created_at" BETWEEN ${fromDate} AND ${toDate}
        ${eventType ? this.prisma.$queryRaw`AND "event_type" = ${eventType}` : this.prisma.$queryRaw``}
      GROUP BY "event_type", day
      ORDER BY day ASC
    `) as Array<{ event_type: string; day: Date; count: bigint }>;
    return rows.map((r) => ({
      event_type: r.event_type,
      day: r.day.toISOString().slice(0, 10),
      count: Number(r.count),
    }));
  }

  /**
   * CSV export of raw analytics_events for the requested window.
   * Hard-capped at 10k rows.
   */
  @Roles('ADMIN')
  @Get('admin/analytics/export.csv')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header(
    'Content-Disposition',
    'attachment; filename="analytics-events.csv"',
  )
  async exportCsv(
    @Res({ passthrough: true }) _res: Response,
    @Query('event_type') eventType?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ): Promise<string> {
    const fromDate = from
      ? new Date(from)
      : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const toDate = to ? new Date(to) : new Date();
    const rows = await this.prisma.analyticsEvent.findMany({
      where: {
        createdAt: { gte: fromDate, lte: toDate },
        ...(eventType ? { eventType } : {}),
      },
      orderBy: { createdAt: 'asc' },
      take: CSV_HARD_CAP,
    });
    const header = ['created_at', 'event_type', 'actor_id', 'payload'].join(',');
    const lines = rows.map((r) =>
      [
        r.createdAt.toISOString(),
        r.eventType,
        r.actorId ?? '',
        csvEscape(JSON.stringify(r.payload)),
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
