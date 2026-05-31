import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService, Viewer } from '../../shared/access-control.service';
import { CategoryService } from '../community/category.service';
import { RoomService } from '../community/room.service';
import {
  ContributionDetailDTO,
  ContributionEvidenceType,
  ContributionStatus,
  ContributionSummaryDTO,
  ResolveDecision,
} from './dto/contribution.dto';

const ALLOWED_BLOCK_TYPES = new Set([
  'OVERVIEW',
  'POPULAR_FORMAT',
  'RECOMMENDED_PARTY_SIZE',
  'MOOD_TIPS',
  'FAQ',
  'CHECKLIST',
  'WARNING',
]);

export interface SubmitContributionInput {
  target_block_id?: string | null;
  proposed_block_type: string;
  proposed_title: string;
  proposed_body: string;
  evidence_type?: ContributionEvidenceType | null;
  evidence_target_id?: string | null;
}

export interface ResolveContributionInput {
  decision: ResolveDecision;
  note?: string;
}

@Injectable()
export class KnowledgeContributionService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
    private readonly categories: CategoryService,
    private readonly rooms: RoomService,
  ) {}

  // -- Submit -------------------------------------------------------------

  async submit(
    categorySlug: string,
    input: SubmitContributionInput,
    contributor: { id: string; roles: string[] },
  ): Promise<ContributionDetailDTO> {
    await this.access.assertCanReadCategoryBySlug(categorySlug, contributor);

    const category = await this.categories.findBySlug(categorySlug);
    const hub = await this.prisma.topicHub.findUnique({
      where: { categoryId: category.id },
    });
    if (!hub) {
      throw new NotFoundException(`Topic hub not found for category: ${categorySlug}`);
    }

    if (!ALLOWED_BLOCK_TYPES.has(input.proposed_block_type)) {
      throw new BadRequestException(`Invalid proposed_block_type: ${input.proposed_block_type}`);
    }
    if (!input.proposed_title?.trim() || !input.proposed_body?.trim()) {
      throw new BadRequestException('proposed_title and proposed_body are required');
    }

    if (input.target_block_id) {
      const block = await this.prisma.knowledgeBlock.findUnique({
        where: { id: input.target_block_id },
      });
      if (!block || block.topicHubId !== hub.id) {
        throw new NotFoundException('target_block_id not found in this hub');
      }
    }

    // Evidence pairing: both or neither
    await this.validateEvidencePair(input.evidence_type ?? null, input.evidence_target_id ?? null);

    const created = await this.prisma.knowledgeContribution.create({
      data: {
        topicHubId: hub.id,
        contributorId: contributor.id,
        targetBlockId: input.target_block_id ?? null,
        proposedBlockType: input.proposed_block_type,
        proposedTitle: input.proposed_title.trim(),
        proposedBody: input.proposed_body.trim(),
        evidenceType: input.evidence_type ?? null,
        evidenceTargetId: input.evidence_target_id ?? null,
      },
    });

    return this.getDetail(created.id);
  }

  // -- Reads --------------------------------------------------------------

  async listMine(
    contributorId: string,
    status?: ContributionStatus,
  ): Promise<ContributionSummaryDTO[]> {
    const rows = await this.prisma.knowledgeContribution.findMany({
      where: { contributorId, ...(status ? { status } : {}) },
      include: {
        contributor: { include: { profile: true } },
        hub: { include: { category: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((r) => this.toSummary(r));
  }

  async listForAdmin(
    status?: ContributionStatus,
    categorySlug?: string,
  ): Promise<ContributionSummaryDTO[]> {
    const where: any = {};
    if (status) where.status = status;
    if (categorySlug) {
      const cat = await this.prisma.category.findUnique({ where: { slug: categorySlug } });
      if (!cat) throw new NotFoundException(`Category not found: ${categorySlug}`);
      const hub = await this.prisma.topicHub.findUnique({ where: { categoryId: cat.id } });
      if (!hub) return [];
      where.topicHubId = hub.id;
    }

    const rows = await this.prisma.knowledgeContribution.findMany({
      where,
      include: {
        contributor: { include: { profile: true } },
        hub: { include: { category: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((r) => this.toSummary(r));
  }

  async getDetail(id: string): Promise<ContributionDetailDTO> {
    const row = await this.prisma.knowledgeContribution.findUnique({
      where: { id },
      include: {
        contributor: { include: { profile: true } },
        resolver: { include: { profile: true } },
        hub: { include: { category: true } },
        targetBlock: true,
      },
    });
    if (!row) {
      throw new NotFoundException(`Contribution not found: ${id}`);
    }

    let evidence: any = null;
    if (row.evidenceType && row.evidenceTargetId) {
      if (row.evidenceType === 'EVENT_CARD') {
        const ec = await this.prisma.eventCard.findUnique({ where: { id: row.evidenceTargetId } });
        if (ec) evidence = this.rooms.toEventCardDTO(ec);
      } else if (row.evidenceType === 'REFERENCE') {
        const rf = await this.prisma.reference.findUnique({ where: { id: row.evidenceTargetId } });
        if (rf) evidence = this.rooms.toReferenceDTO(rf);
      }
    }

    return {
      ...this.toSummary(row),
      proposed_body: row.proposedBody,
      current_block: row.targetBlock
        ? {
            id: row.targetBlock.id,
            block_type: row.targetBlock.blockType,
            title: row.targetBlock.title,
            body: row.targetBlock.body,
          }
        : null,
      evidence,
      curator_note: row.curatorNote,
      resolver_nickname: row.resolver?.profile?.nickname ?? null,
      snapshot:
        row.snapshotBlockType !== null && row.snapshotTitle !== null && row.snapshotBody !== null
          ? {
              block_type: row.snapshotBlockType,
              title: row.snapshotTitle,
              body: row.snapshotBody,
            }
          : null,
    };
  }

  // -- Withdraw -----------------------------------------------------------

  async withdraw(id: string, userId: string): Promise<void> {
    const row = await this.prisma.knowledgeContribution.findUnique({ where: { id } });
    if (!row) throw new NotFoundException(`Contribution not found: ${id}`);
    if (row.contributorId !== userId) {
      throw new ForbiddenException('Only the contributor can withdraw');
    }
    if (row.status !== 'PENDING') {
      throw new ConflictException(`Cannot withdraw a ${row.status} contribution`);
    }
    await this.prisma.knowledgeContribution.update({
      where: { id },
      data: { status: 'WITHDRAWN' },
    });
  }

  // -- Resolve (curator) --------------------------------------------------

  async resolve(
    id: string,
    input: ResolveContributionInput,
    resolverId: string,
  ): Promise<ContributionDetailDTO> {
    const existing = await this.prisma.knowledgeContribution.findUnique({
      where: { id },
      include: {
        hub: { include: { category: { include: { space: true } } } },
        targetBlock: true,
      },
    });
    if (!existing) throw new NotFoundException(`Contribution not found: ${id}`);
    if (existing.status !== 'PENDING') {
      throw new ConflictException(`Contribution already ${existing.status.toLowerCase()}`);
    }
    // P2.2: prevent score inflation via self-resolve. A contributor must
    // never sit on both sides of the curation flow for the same row.
    if (existing.contributorId === resolverId) {
      throw new ForbiddenException(
        'You cannot resolve your own contribution',
      );
    }

    const spaceAccessPolicy = existing.hub.category.space.accessPolicy;

    if (input.decision === 'APPROVE') {
      await this._applyApprove(existing, resolverId, input.note, spaceAccessPolicy);
    } else {
      const status =
        input.decision === 'REJECT' ? 'REJECTED'
        : input.decision === 'REQUEST_CHANGES' ? 'NEEDS_CHANGES'
        : (() => { throw new BadRequestException(`Invalid decision: ${input.decision}`); })();
      await this.prisma.$transaction(async (tx) => {
        await tx.knowledgeContribution.update({
          where: { id },
          data: {
            status,
            curatorNote: input.note ?? null,
            resolvedBy: resolverId,
            resolvedAt: new Date(),
          },
        });
        await this._bumpReputation(tx, existing.contributorId, status);
        await tx.notification.create({
          data: {
            userId: existing.contributorId,
            type: 'CONTRIBUTION_RESOLVED',
            payload: {
              contributionId: id,
              topicHubTitle: existing.hub.title,
              decision: status,
              curatorNote: input.note ?? null,
              spaceAccessPolicy,
            },
          },
        });
      });
    }

    return this.getDetail(id);
  }

  // -- Internals ----------------------------------------------------------

  private async _applyApprove(
    contribution: {
      id: string;
      topicHubId: string;
      contributorId: string;
      targetBlockId: string | null;
      proposedBlockType: string;
      proposedTitle: string;
      proposedBody: string;
      hub: { title: string };
      targetBlock: {
        id: string;
        blockType: string;
        title: string;
        body: string;
        sortOrder: number;
      } | null;
    },
    resolverId: string,
    note: string | undefined,
    spaceAccessPolicy: string,
  ): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      let revisionBlockId: string;
      if (contribution.targetBlockId && contribution.targetBlock) {
        // Edit existing: snapshot the current content before overwriting.
        await tx.knowledgeBlock.update({
          where: { id: contribution.targetBlockId },
          data: {
            blockType: contribution.proposedBlockType,
            title: contribution.proposedTitle,
            body: contribution.proposedBody,
          },
        });
        await tx.knowledgeContribution.update({
          where: { id: contribution.id },
          data: {
            status: 'APPROVED',
            curatorNote: note ?? null,
            resolvedBy: resolverId,
            resolvedAt: new Date(),
            snapshotBlockType: contribution.targetBlock.blockType,
            snapshotTitle: contribution.targetBlock.title,
            snapshotBody: contribution.targetBlock.body,
          },
        });
        revisionBlockId = contribution.targetBlockId;
      } else {
        // Propose new: create a new block at end of hub's sort_order.
        const max = await tx.knowledgeBlock.aggregate({
          where: { topicHubId: contribution.topicHubId },
          _max: { sortOrder: true },
        });
        const nextOrder = (max._max.sortOrder ?? 0) + 1;
        const created = await tx.knowledgeBlock.create({
          data: {
            topicHubId: contribution.topicHubId,
            blockType: contribution.proposedBlockType,
            title: contribution.proposedTitle,
            body: contribution.proposedBody,
            sortOrder: nextOrder,
          },
        });
        await tx.knowledgeContribution.update({
          where: { id: contribution.id },
          data: {
            status: 'APPROVED',
            curatorNote: note ?? null,
            resolvedBy: resolverId,
            resolvedAt: new Date(),
          },
        });
        revisionBlockId = created.id;
      }

      // P2.1: record the audit revision row. Version is the next integer
      // for this block — relies on the (block_id, version) unique
      // constraint to surface concurrent-approval races as ConflictError.
      const maxVersion = await tx.knowledgeBlockRevision.aggregate({
        where: { blockId: revisionBlockId },
        _max: { version: true },
      });
      await tx.knowledgeBlockRevision.create({
        data: {
          blockId: revisionBlockId,
          version: (maxVersion._max.version ?? 0) + 1,
          blockType: contribution.proposedBlockType,
          title: contribution.proposedTitle,
          body: contribution.proposedBody,
          changedById: contribution.contributorId,
          contributionId: contribution.id,
          source: 'CONTRIBUTION',
        },
      });

      // P2.2: bump contributor reputation in lockstep with the
      // contribution status change.
      await this._bumpReputation(tx, contribution.contributorId, 'APPROVED');

      // Notify contributor of approval
      if (contribution.contributorId !== resolverId) {
        await tx.notification.create({
          data: {
            userId: contribution.contributorId,
            type: 'CONTRIBUTION_RESOLVED',
            payload: {
              contributionId: contribution.id,
              topicHubTitle: contribution.hub.title,
              decision: 'APPROVED',
              curatorNote: note ?? null,
              spaceAccessPolicy,
            },
          },
        });
      }
    });
  }

  /**
   * P2.2: bump the contributor's aggregate counters by 1 for the
   * decided status, then recompute weighted_score from all four
   * counts so the column never drifts from the formula (defense in
   * depth — a missed increment somewhere else is self-healing on the
   * next resolve).
   *
   * Skipping `withdrawn` from `withdraw()` is intentional: the
   * contributor pulled the row themselves; the score formula's
   * -0.2 penalty is reserved for resolution-flow withdrawals. To
   * apply it from `withdraw()`, call this helper there too — we
   * intentionally do NOT today so users can experiment without a
   * permanent score hit.
   */
  private async _bumpReputation(
    tx: Prisma.TransactionClient,
    userId: string,
    status: string,
  ): Promise<void> {
    const data: Prisma.ContributionReputationUpdateInput = {
      lastResolvedAt: new Date(),
    };
    const createData: Prisma.ContributionReputationCreateInput = {
      user: { connect: { id: userId } },
      lastResolvedAt: new Date(),
    };
    switch (status) {
      case 'APPROVED':
        data.approvedCount = { increment: 1 };
        createData.approvedCount = 1;
        break;
      case 'REJECTED':
        data.rejectedCount = { increment: 1 };
        createData.rejectedCount = 1;
        break;
      case 'NEEDS_CHANGES':
        data.needsChangesCount = { increment: 1 };
        createData.needsChangesCount = 1;
        break;
      case 'WITHDRAWN':
        data.withdrawnCount = { increment: 1 };
        createData.withdrawnCount = 1;
        break;
      default:
        return;
    }
    await tx.contributionReputation.upsert({
      where: { userId },
      create: createData,
      update: data,
    });
    await tx.$executeRaw`
      UPDATE "contribution_reputation"
      SET "weighted_score" = GREATEST(
          0::numeric,
            "approved_count" * 3
          - "rejected_count" * 1
          - "needs_changes_count" * 0.5
          - "withdrawn_count" * 0.2
      )::decimal(10,2)
      WHERE "user_id" = ${userId}::uuid
    `;
  }

  private async validateEvidencePair(
    evidenceType: ContributionEvidenceType | null,
    evidenceTargetId: string | null,
  ): Promise<void> {
    if (evidenceType === null && evidenceTargetId === null) return;
    if (evidenceType === null || evidenceTargetId === null) {
      throw new BadRequestException(
        'evidence_type and evidence_target_id must be set together (or both omitted)',
      );
    }
    if (evidenceType === 'EVENT_CARD') {
      const ec = await this.prisma.eventCard.findUnique({ where: { id: evidenceTargetId } });
      if (!ec) throw new NotFoundException('evidence event card not found');
    } else if (evidenceType === 'REFERENCE') {
      const rf = await this.prisma.reference.findUnique({ where: { id: evidenceTargetId } });
      if (!rf) throw new NotFoundException('evidence reference not found');
    } else {
      throw new BadRequestException(`Unsupported evidence_type: ${evidenceType}`);
    }
  }

  private toSummary(row: any): ContributionSummaryDTO {
    return {
      id: row.id,
      topic_hub_id: row.topicHubId,
      category_slug: row.hub?.category?.slug ?? '',
      contributor: {
        id: row.contributorId,
        nickname: row.contributor?.profile?.nickname ?? '',
      },
      target_block_id: row.targetBlockId,
      proposed_block_type: row.proposedBlockType,
      proposed_title: row.proposedTitle,
      status: row.status,
      evidence_type: row.evidenceType,
      has_evidence: row.evidenceType !== null,
      created_at: (row.createdAt as Date).toISOString(),
      resolved_at: row.resolvedAt ? (row.resolvedAt as Date).toISOString() : null,
    };
  }
}
