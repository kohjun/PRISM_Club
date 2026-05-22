import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma.service';
import {
  AccessControlService,
  Viewer,
} from '../../shared/access-control.service';
import { AnalyticsService } from '../analytics/analytics.service';
import {
  ApplicationsListDTO,
  MyApplicationEntryDTO,
  MyApplicationsListDTO,
  RecruitmentApplicationDTO,
  RecruitmentApplicationStatus,
} from './dto/recruitment.dto';

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;
const MAX_MESSAGE_LEN = 1000;

/**
 * P3.6 recruitment application service.
 *
 * Apply / withdraw / list / decide flows for RECRUITMENT posts. Lives
 * alongside PostService because it shares the post + access gates,
 * but writes its own rows under the dedicated recruitment_posts +
 * recruitment_applications tables.
 */
@Injectable()
export class RecruitmentService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
    private readonly analytics: AnalyticsService,
  ) {}

  // ---- Applicant side --------------------------------------------------

  async apply(
    postId: string,
    applicant: Viewer & { id: string },
    message: string | null,
  ): Promise<RecruitmentApplicationDTO> {
    const post = await this._loadAccessiblePost(postId, applicant);
    if (post.recruitment == null) {
      throw new BadRequestException('Post is not a recruitment post');
    }
    if (post.authorId === applicant.id) {
      throw new ForbiddenException('You cannot apply to your own post');
    }
    if (post.recruitment.status !== 'OPEN') {
      throw new ConflictException(
        `Recruitment is ${post.recruitment.status.toLowerCase()}`,
      );
    }
    const trimmedMessage =
      message !== null && message.trim().length > 0
        ? message.trim().slice(0, MAX_MESSAGE_LEN)
        : null;

    const row = await this.prisma.recruitmentApplication.upsert({
      where: { postId_applicantId: { postId, applicantId: applicant.id } },
      create: {
        postId,
        applicantId: applicant.id,
        message: trimmedMessage,
        status: 'PENDING',
      },
      update: {
        message: trimmedMessage,
        // Re-applying after withdrawal moves the row back to PENDING.
        status: 'PENDING',
      },
      include: { applicant: { include: { profile: true } } },
    });
    this.analytics.record({
      actorId: applicant.id,
      eventType: 'RECRUITMENT_APPLIED',
      payload: { post_id: postId },
    });
    return this.toDTO(row);
  }

  async withdraw(
    postId: string,
    applicant: Viewer & { id: string },
  ): Promise<{ ok: boolean }> {
    await this._loadAccessiblePost(postId, applicant);
    await this.prisma.recruitmentApplication.updateMany({
      where: { postId, applicantId: applicant.id, status: 'PENDING' },
      data: { status: 'WITHDRAWN' },
    });
    return { ok: true };
  }

  async listMine(
    applicantId: string,
    opts: { status?: string; cursor?: string; limit?: number } = {},
  ): Promise<MyApplicationsListDTO> {
    const limit = Math.max(1, Math.min(opts.limit ?? DEFAULT_LIMIT, MAX_LIMIT));
    const status = this._normalizeStatusFilter(opts.status);
    const rows = await this.prisma.recruitmentApplication.findMany({
      where: { applicantId, ...(status ? { status } : {}) },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(opts.cursor
        ? { cursor: { id: opts.cursor }, skip: 1 }
        : {}),
      include: {
        applicant: { include: { profile: true } },
        recruitmentPost: {
          include: { post: { include: { room: true } } },
        },
      },
    });
    const hasMore = rows.length > limit;
    const sliced = hasMore ? rows.slice(0, limit) : rows;
    const items: MyApplicationEntryDTO[] = sliced.map((r) => ({
      application: this.toDTO(r),
      post: {
        id: r.recruitmentPost.post.id,
        body_preview:
          r.recruitmentPost.post.body.length > 80
            ? `${r.recruitmentPost.post.body.slice(0, 80)}…`
            : r.recruitmentPost.post.body,
        room_slug: r.recruitmentPost.post.room.slug,
        status: r.recruitmentPost.status,
      },
    }));
    return {
      items,
      next_cursor: hasMore ? sliced[sliced.length - 1].id : null,
    };
  }

  // ---- Author / admin side --------------------------------------------

  async listApplications(
    postId: string,
    viewer: Viewer & { id: string },
    opts: { status?: string; cursor?: string; limit?: number } = {},
  ): Promise<ApplicationsListDTO> {
    const post = await this._loadAccessiblePost(postId, viewer);
    if (post.recruitment == null) {
      throw new BadRequestException('Post is not a recruitment post');
    }
    this._assertAuthorOrAdmin(post.authorId, viewer);

    const limit = Math.max(1, Math.min(opts.limit ?? DEFAULT_LIMIT, MAX_LIMIT));
    const status = this._normalizeStatusFilter(opts.status);
    const rows = await this.prisma.recruitmentApplication.findMany({
      where: { postId, ...(status ? { status } : {}) },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(opts.cursor
        ? { cursor: { id: opts.cursor }, skip: 1 }
        : {}),
      include: { applicant: { include: { profile: true } } },
    });
    const hasMore = rows.length > limit;
    const sliced = hasMore ? rows.slice(0, limit) : rows;
    const acceptedCount = await this.prisma.recruitmentApplication.count({
      where: { postId, status: 'ACCEPTED' },
    });
    return {
      items: sliced.map(this.toDTO),
      next_cursor: hasMore ? sliced[sliced.length - 1].id : null,
      recruitment_status: post.recruitment.status,
      accepted_count: acceptedCount,
      capacity: post.recruitment.capacity,
    };
  }

  /**
   * Author / admin decides on a single application. Wraps the
   * status update + capacity-driven FILLED transition + applicant
   * notification in one transaction so partial updates don't drift.
   */
  async decide(
    applicationId: string,
    decision: 'ACCEPT' | 'REJECT',
    viewer: Viewer & { id: string },
  ): Promise<RecruitmentApplicationDTO> {
    const app = await this.prisma.recruitmentApplication.findUnique({
      where: { id: applicationId },
      include: {
        recruitmentPost: {
          include: {
            post: {
              include: {
                room: { include: { category: { include: { space: true } } } },
              },
            },
          },
        },
        applicant: { include: { profile: true } },
      },
    });
    if (!app) {
      throw new NotFoundException(`Application not found: ${applicationId}`);
    }
    // Author or admin only.
    this._assertAuthorOrAdmin(app.recruitmentPost.post.authorId, viewer);
    if (app.status !== 'PENDING') {
      throw new ConflictException(
        `Application already ${app.status.toLowerCase()}`,
      );
    }
    const newStatus: RecruitmentApplicationStatus =
      decision === 'ACCEPT' ? 'ACCEPTED' : 'REJECTED';
    const spaceAccessPolicy =
      app.recruitmentPost.post.room.category.space.accessPolicy;

    const updated = await this.prisma.$transaction(async (tx) => {
      const u = await tx.recruitmentApplication.update({
        where: { id: applicationId },
        data: { status: newStatus },
        include: { applicant: { include: { profile: true } } },
      });

      // Capacity-driven auto-FILLED on ACCEPT.
      if (newStatus === 'ACCEPTED' && app.recruitmentPost.capacity != null) {
        const acceptedNow = await tx.recruitmentApplication.count({
          where: { postId: app.postId, status: 'ACCEPTED' },
        });
        if (
          acceptedNow >= app.recruitmentPost.capacity &&
          app.recruitmentPost.status === 'OPEN'
        ) {
          await tx.recruitmentPost.update({
            where: { postId: app.postId },
            data: { status: 'FILLED' },
          });
          // Mirror onto the legacy JSON for backward-compat readers.
          await tx.post.update({
            where: { id: app.postId },
            data: {
              recruitmentFields: this._mergeLegacyStatus(
                app.recruitmentPost.post.recruitmentFields,
                'FILLED',
              ),
            },
          });
        }
      }

      // Notify the applicant.
      await tx.notification.create({
        data: {
          userId: app.applicantId,
          type: 'RECRUITMENT_STATUS_CHANGED',
          payload: {
            applicationId,
            postId: app.postId,
            decision: newStatus,
            spaceAccessPolicy,
          },
        },
      });
      return u;
    });

    this.analytics.record({
      actorId: viewer.id,
      eventType: 'RECRUITMENT_DECISION_MADE',
      payload: { application_id: applicationId, decision: newStatus },
    });
    return this.toDTO(updated);
  }

  // ---- Helpers --------------------------------------------------------

  private async _loadAccessiblePost(
    postId: string,
    viewer: Viewer,
  ): Promise<{
    id: string;
    authorId: string;
    status: string;
    recruitment: {
      capacity: number | null;
      status: string;
    } | null;
  }> {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      include: {
        room: { include: { category: { include: { space: true } } } },
        recruitment: true,
      },
    });
    if (!post || post.status === 'DELETED' || post.status === 'HIDDEN') {
      throw new NotFoundException(`Post not found: ${postId}`);
    }
    if (
      !this.access
        .accessPoliciesAllowedFor(viewer)
        .includes(post.room.category.space.accessPolicy)
    ) {
      throw new NotFoundException(`Post not found: ${postId}`);
    }
    return {
      id: post.id,
      authorId: post.authorId,
      status: post.status,
      recruitment: post.recruitment,
    };
  }

  private _assertAuthorOrAdmin(authorId: string, viewer: Viewer & { id: string }): void {
    if (viewer.id === authorId) return;
    if (
      viewer.roles.includes('ADMIN') ||
      viewer.roles.includes('MODERATOR') ||
      viewer.roles.includes('CURATOR')
    ) {
      return;
    }
    throw new ForbiddenException(
      'Only the author or an admin can manage these applications',
    );
  }

  private _normalizeStatusFilter(s?: string): string | undefined {
    if (!s) return undefined;
    const up = s.toUpperCase();
    if (
      up === 'PENDING' ||
      up === 'ACCEPTED' ||
      up === 'REJECTED' ||
      up === 'WITHDRAWN'
    ) {
      return up;
    }
    return undefined;
  }

  private _mergeLegacyStatus(
    existing: unknown,
    newStatus: string,
  ): Prisma.InputJsonValue {
    if (existing && typeof existing === 'object') {
      return {
        ...(existing as Record<string, unknown>),
        status: newStatus,
      } as Prisma.InputJsonValue;
    }
    return { status: newStatus } as Prisma.InputJsonValue;
  }

  private toDTO = (row: {
    id: string;
    postId: string;
    applicantId: string;
    message: string | null;
    status: string;
    createdAt: Date;
    updatedAt: Date;
    applicant?: { id: string; profile: { nickname: string | null } | null } | null;
  }): RecruitmentApplicationDTO => ({
    id: row.id,
    post_id: row.postId,
    applicant: {
      id: row.applicantId,
      nickname: row.applicant?.profile?.nickname ?? null,
    },
    message: row.message,
    status: row.status as RecruitmentApplicationStatus,
    created_at: row.createdAt.toISOString(),
    updated_at: row.updatedAt.toISOString(),
  });
}
