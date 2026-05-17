import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService, Viewer } from '../../shared/access-control.service';
import { AnalyticsService } from '../analytics/analytics.service';
import {
  CreateReportInput,
  ModerationActionDTO,
  ReportDTO,
  ReportDetailDTO,
  ReportListDTO,
  ReportStatus,
  ReportTargetSummaryDTO,
  ReportTargetType,
  ResolveReportInput,
} from './dto/moderation.dto';

const VALID_TARGET_TYPES: ReportTargetType[] = [
  'POST',
  'REPLY',
  'ROOM',
  'USER',
  'REFERENCE',
];

const VALID_ACTIONS = ['HIDE', 'RESTORE', 'DISMISS'] as const;
type ActionType = (typeof VALID_ACTIONS)[number];

const REASON_MAX = 80;
const DETAILS_MAX = 1000;
const NOTE_MAX = 1000;

@Injectable()
export class ReportService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
    private readonly analytics: AnalyticsService,
  ) {}

  isModerator(viewer: Viewer): boolean {
    return (
      viewer.roles.includes('MODERATOR') || viewer.roles.includes('ADMIN')
    );
  }

  async createReport(
    input: CreateReportInput,
    viewer: Viewer & { id: string },
  ): Promise<ReportDTO> {
    const type = input.target_type as ReportTargetType;
    if (!VALID_TARGET_TYPES.includes(type)) {
      throw new BadRequestException(
        `Invalid target_type: ${input.target_type}`,
      );
    }
    if (!input.reason || input.reason.trim().length === 0) {
      throw new BadRequestException('reason is required');
    }
    if (input.reason.length > REASON_MAX) {
      throw new BadRequestException(
        `reason must be at most ${REASON_MAX} characters`,
      );
    }
    if (input.details && input.details.length > DETAILS_MAX) {
      throw new BadRequestException(
        `details must be at most ${DETAILS_MAX} characters`,
      );
    }

    // Verify the target exists; also disallow reporting self for USER.
    await this.assertTargetExists(type, input.target_id, viewer);

    // Reject duplicate OPEN report by same reporter for same target.
    const existing = await this.prisma.report.findFirst({
      where: {
        reporterId: viewer.id,
        targetType: type,
        targetId: input.target_id,
        status: 'OPEN',
      },
    });
    if (existing) {
      throw new ConflictException(
        'You already have an open report for this content',
      );
    }

    const row = await this.prisma.report.create({
      data: {
        reporterId: viewer.id,
        targetType: type,
        targetId: input.target_id,
        reason: input.reason.trim(),
        details: input.details?.trim() ?? null,
      },
      include: { reporter: { include: { profile: true } } },
    });
    this.analytics.record({
      actorId: viewer.id,
      eventType: 'REPORT_CREATED',
      payload: {
        report_id: row.id,
        target_type: type,
        target_id: input.target_id,
      },
    });
    return this.toDTO(row);
  }

  async listMine(viewerId: string): Promise<ReportListDTO> {
    const rows = await this.prisma.report.findMany({
      where: { reporterId: viewerId },
      orderBy: { createdAt: 'desc' },
      include: { reporter: { include: { profile: true } } },
    });
    return { items: rows.map((r) => this.toDTO(r)) };
  }

  async listQueue(
    viewer: Viewer,
    opts: { status?: string } = {},
  ): Promise<ReportListDTO> {
    if (!this.isModerator(viewer)) {
      throw new ForbiddenException('Moderator access required');
    }
    const where: { status?: string } = {};
    if (opts.status) where.status = opts.status;
    else where.status = 'OPEN';
    const rows = await this.prisma.report.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: { reporter: { include: { profile: true } } },
    });
    return { items: rows.map((r) => this.toDTO(r)) };
  }

  async getDetail(id: string, viewer: Viewer): Promise<ReportDetailDTO> {
    if (!this.isModerator(viewer)) {
      throw new ForbiddenException('Moderator access required');
    }
    const row = await this.prisma.report.findUnique({
      where: { id },
      include: { reporter: { include: { profile: true } } },
    });
    if (!row) throw new NotFoundException(`Report not found: ${id}`);

    const target = await this.resolveTargetSummary(
      row.targetType as ReportTargetType,
      row.targetId,
    );
    const actions = await this.prisma.moderationAction.findMany({
      where: { targetType: row.targetType, targetId: row.targetId },
      orderBy: { createdAt: 'desc' },
      include: { actor: { include: { profile: true } } },
    });

    return {
      ...this.toDTO(row),
      target,
      actions: actions.map((a) => this.toActionDTO(a)),
    };
  }

  async resolve(
    reportId: string,
    input: ResolveReportInput,
    viewer: Viewer & { id: string },
  ): Promise<ReportDetailDTO> {
    if (!this.isModerator(viewer)) {
      throw new ForbiddenException('Moderator access required');
    }
    const action = input.action as ActionType;
    if (!VALID_ACTIONS.includes(action)) {
      throw new BadRequestException(`Invalid action: ${input.action}`);
    }
    if (input.note && input.note.length > NOTE_MAX) {
      throw new BadRequestException(
        `note must be at most ${NOTE_MAX} characters`,
      );
    }

    const report = await this.prisma.report.findUnique({
      where: { id: reportId },
    });
    if (!report) {
      throw new NotFoundException(`Report not found: ${reportId}`);
    }
    if (report.status !== 'OPEN') {
      throw new BadRequestException('Report is already resolved');
    }

    const targetType = report.targetType as ReportTargetType;
    const newStatus: ReportStatus = 'RESOLVED';
    const resolution =
      action === 'HIDE'
        ? 'HIDDEN'
        : action === 'RESTORE'
          ? 'RESTORED'
          : 'DISMISSED';
    const noteTrim = input.note?.trim();

    await this.prisma.$transaction(async (tx) => {
      // Apply moderation effect to target.
      if (action === 'HIDE') {
        if (targetType === 'POST') {
          await tx.post.updateMany({
            where: { id: report.targetId },
            data: { status: 'HIDDEN' },
          });
        } else if (targetType === 'REPLY') {
          await tx.reply.updateMany({
            where: { id: report.targetId },
            data: { status: 'HIDDEN' },
          });
        }
        // ROOM/USER/REFERENCE hide are deferred (no schema flag yet).
      } else if (action === 'RESTORE') {
        if (targetType === 'POST') {
          await tx.post.updateMany({
            where: { id: report.targetId, status: 'HIDDEN' },
            data: { status: 'VISIBLE' },
          });
        } else if (targetType === 'REPLY') {
          await tx.reply.updateMany({
            where: { id: report.targetId, status: 'HIDDEN' },
            data: { status: 'VISIBLE' },
          });
        }
      }

      await tx.moderationAction.create({
        data: {
          actorId: viewer.id,
          action,
          targetType: report.targetType,
          targetId: report.targetId,
          reportId: report.id,
          note: noteTrim ?? null,
        },
      });

      await tx.report.update({
        where: { id: report.id },
        data: {
          status: newStatus,
          resolution,
          resolvedBy: viewer.id,
          resolvedAt: new Date(),
          resolverNote: noteTrim ?? null,
        },
      });

      // Notify the reporter that their report was resolved (cheap, fire-and-forget).
      if (report.reporterId !== viewer.id) {
        await tx.notification.create({
          data: {
            userId: report.reporterId,
            type: 'REPORT_RESOLVED',
            payload: {
              reportId: report.id,
              targetType: report.targetType,
              targetId: report.targetId,
              resolution,
              note: noteTrim ?? null,
            },
          },
        });
      }
    });

    return this.getDetail(reportId, viewer);
  }

  private async resolveTargetSummary(
    type: ReportTargetType,
    id: string,
  ): Promise<ReportTargetSummaryDTO> {
    if (type === 'POST') {
      const p = await this.prisma.post.findUnique({ where: { id } });
      return {
        type,
        id,
        preview: p ? p.body.slice(0, 80) : '(deleted)',
        status: p?.status ?? null,
        exists: !!p,
      };
    }
    if (type === 'REPLY') {
      const r = await this.prisma.reply.findUnique({ where: { id } });
      return {
        type,
        id,
        preview: r ? r.body.slice(0, 80) : '(deleted)',
        status: r?.status ?? null,
        exists: !!r,
      };
    }
    if (type === 'ROOM') {
      const r = await this.prisma.room.findUnique({ where: { id } });
      return {
        type,
        id,
        preview: r?.name ?? '(deleted)',
        status: null,
        exists: !!r,
      };
    }
    if (type === 'USER') {
      const u = await this.prisma.user.findUnique({
        where: { id },
        include: { profile: true },
      });
      return {
        type,
        id,
        preview: u?.profile?.nickname ?? '(deleted)',
        status: u?.status ?? null,
        exists: !!u,
      };
    }
    if (type === 'REFERENCE') {
      const r = await this.prisma.reference.findUnique({ where: { id } });
      return {
        type,
        id,
        preview: r?.title ?? '(deleted)',
        status: r?.status ?? null,
        exists: !!r,
      };
    }
    return { type, id, preview: '(unknown)', status: null, exists: false };
  }

  private async assertTargetExists(
    type: ReportTargetType,
    id: string,
    viewer: Viewer & { id: string },
  ): Promise<void> {
    if (type === 'USER' && id === viewer.id) {
      throw new BadRequestException('Cannot report yourself');
    }
    let found = false;
    if (type === 'POST') {
      found = !!(await this.prisma.post.findUnique({
        where: { id },
        select: { id: true },
      }));
    } else if (type === 'REPLY') {
      found = !!(await this.prisma.reply.findUnique({
        where: { id },
        select: { id: true },
      }));
    } else if (type === 'ROOM') {
      found = !!(await this.prisma.room.findUnique({
        where: { id },
        select: { id: true },
      }));
    } else if (type === 'USER') {
      found = !!(await this.prisma.user.findUnique({
        where: { id },
        select: { id: true },
      }));
    } else if (type === 'REFERENCE') {
      found = !!(await this.prisma.reference.findUnique({
        where: { id },
        select: { id: true },
      }));
    }
    if (!found) {
      throw new NotFoundException(`${type} not found: ${id}`);
    }
  }

  private toDTO(row: {
    id: string;
    reporterId: string;
    reporter: { id: string; profile: { nickname: string } | null } | null;
    targetType: string;
    targetId: string;
    reason: string;
    details: string | null;
    status: string;
    resolution: string | null;
    resolvedBy: string | null;
    resolvedAt: Date | null;
    resolverNote: string | null;
    createdAt: Date;
  }): ReportDTO {
    return {
      id: row.id,
      reporter: {
        id: row.reporterId,
        nickname: row.reporter?.profile?.nickname ?? null,
      },
      target_type: row.targetType as ReportTargetType,
      target_id: row.targetId,
      reason: row.reason,
      details: row.details,
      status: row.status as ReportStatus,
      resolution: row.resolution,
      resolved_by: row.resolvedBy,
      resolved_at: row.resolvedAt?.toISOString() ?? null,
      resolver_note: row.resolverNote,
      created_at: row.createdAt.toISOString(),
    };
  }

  private toActionDTO(row: {
    id: string;
    actorId: string;
    actor: { profile: { nickname: string } | null } | null;
    action: string;
    targetType: string;
    targetId: string;
    reportId: string | null;
    note: string | null;
    createdAt: Date;
  }): ModerationActionDTO {
    return {
      id: row.id,
      actor: {
        id: row.actorId,
        nickname: row.actor?.profile?.nickname ?? null,
      },
      action: row.action as 'HIDE' | 'RESTORE' | 'DISMISS',
      target_type: row.targetType as ReportTargetType,
      target_id: row.targetId,
      report_id: row.reportId,
      note: row.note,
      created_at: row.createdAt.toISOString(),
    };
  }
}
