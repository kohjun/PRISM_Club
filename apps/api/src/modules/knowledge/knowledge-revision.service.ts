import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import {
  AccessControlService,
  Viewer,
} from '../../shared/access-control.service';
import {
  RevisionDTO,
  RevisionListDTO,
  RevisionSource,
} from './dto/revision.dto';

const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 100;

/**
 * Revision history reader (P2.1).
 *
 * The author of each revision row is hydrated through the User /
 * Profile join, but never includes email / phone / oauth_id — only
 * the public-facing nickname.
 */
@Injectable()
export class KnowledgeRevisionService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
  ) {}

  async listForBlock(
    blockId: string,
    viewer: Viewer,
    opts: { cursor?: string; limit?: number } = {},
  ): Promise<RevisionListDTO> {
    const block = await this.prisma.knowledgeBlock.findUnique({
      where: { id: blockId },
      include: { hub: { include: { category: { include: { space: true } } } } },
    });
    if (!block) {
      throw new NotFoundException(`Knowledge block not found: ${blockId}`);
    }
    if (
      !this.access
        .accessPoliciesAllowedFor(viewer)
        .includes(block.hub.category.space.accessPolicy)
    ) {
      throw new NotFoundException(`Knowledge block not found: ${blockId}`);
    }

    const limit = Math.max(1, Math.min(opts.limit ?? DEFAULT_LIMIT, MAX_LIMIT));
    const rows = await this.prisma.knowledgeBlockRevision.findMany({
      where: { blockId },
      orderBy: [
        { changedAt: 'desc' },
        { version: 'desc' },
      ],
      take: limit + 1,
      ...(opts.cursor
        ? { cursor: { id: opts.cursor }, skip: 1 }
        : {}),
      include: {
        changedBy: { include: { profile: true } },
      },
    });

    const hasMore = rows.length > limit;
    const sliced = hasMore ? rows.slice(0, limit) : rows;
    return {
      items: sliced.map(this.toDTO),
      next_cursor: hasMore ? sliced[sliced.length - 1].id : null,
    };
  }

  /**
   * Admin variant that bypasses the space access policy. Used by the
   * curator dashboard so moderators can audit history across spaces
   * they would otherwise need a separate role to view.
   */
  async listForBlockAdmin(
    blockId: string,
    opts: { cursor?: string; limit?: number } = {},
  ): Promise<RevisionListDTO> {
    const exists = await this.prisma.knowledgeBlock.findUnique({
      where: { id: blockId },
      select: { id: true },
    });
    if (!exists) {
      throw new NotFoundException(`Knowledge block not found: ${blockId}`);
    }
    const limit = Math.max(1, Math.min(opts.limit ?? DEFAULT_LIMIT, MAX_LIMIT));
    const rows = await this.prisma.knowledgeBlockRevision.findMany({
      where: { blockId },
      orderBy: [
        { changedAt: 'desc' },
        { version: 'desc' },
      ],
      take: limit + 1,
      ...(opts.cursor
        ? { cursor: { id: opts.cursor }, skip: 1 }
        : {}),
      include: {
        changedBy: { include: { profile: true } },
      },
    });
    const hasMore = rows.length > limit;
    const sliced = hasMore ? rows.slice(0, limit) : rows;
    return {
      items: sliced.map(this.toDTO),
      next_cursor: hasMore ? sliced[sliced.length - 1].id : null,
    };
  }

  private toDTO = (row: {
    id: string;
    blockId: string;
    version: number;
    blockType: string;
    title: string;
    body: string;
    source: string;
    changedById: string | null;
    changedAt: Date;
    contributionId: string | null;
    changedBy: {
      id: string;
      profile: { nickname: string | null } | null;
    } | null;
  }): RevisionDTO => {
    const source = this.assertSource(row.source);
    return {
      id: row.id,
      block_id: row.blockId,
      version: row.version,
      block_type: row.blockType,
      title: row.title,
      body: row.body,
      source,
      changed_by: row.changedBy
        ? {
            id: row.changedBy.id,
            nickname: row.changedBy.profile?.nickname ?? null,
          }
        : null,
      changed_at: row.changedAt.toISOString(),
      contribution_id: row.contributionId,
    };
  };

  private assertSource(s: string): RevisionSource {
    if (s === 'SEED' || s === 'CONTRIBUTION' || s === 'ADMIN') return s;
    throw new BadRequestException(`Unknown revision source: ${s}`);
  }
}
