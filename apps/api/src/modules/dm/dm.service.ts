import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import {
  AccessControlService,
  Viewer,
} from '../../shared/access-control.service';
import { AnalyticsService } from '../analytics/analytics.service';
import { RateLimitService } from '../../shared/rate-limit.service';
import {
  BlockMuteService,
  assertNotBlocked,
} from '../../shared/block-mute.service';
import { NotificationService } from '../notifications/notification.service';
import { AutoModerationService } from '../moderation/auto-moderation.service';
import {
  CreateDmChannelInput,
  DmChannelDTO,
  DmChannelListDTO,
  DmMessageDTO,
  DmMessageListDTO,
} from './dto/dm.dto';

const VALID_SCOPES = ['RECRUITMENT', 'CONTRIBUTION'];
const BODY_MAX = 2000;
const MESSAGES_PAGE = 50;
// DM is the highest-abuse new surface, so it ships with a tighter cap
// than the tier default AND enforces day-1 (force) regardless of the
// app-wide RATE_LIMIT_ENABLED shadow flag.
const DM_RATE_PER_MIN = 20;

type Profiled = { id: string; profile: { nickname: string | null } | null };
type ChannelWithParties = {
  id: string;
  scope: string;
  refId: string;
  partyAId: string;
  partyBId: string;
  spaceAccessPolicy: string;
  status: string;
  lastMessageAt: Date | null;
  createdAt: Date;
  partyA: Profiled;
  partyB: Profiled;
};

/**
 * P6.9 — Scoped DM. Workflow-bounded private 1:1 messaging:
 *   - RECRUITMENT: an applicant ↔ the recruitment-post author.
 *   - CONTRIBUTION: a proposer ↔ the curator who set NEEDS_CHANGES.
 *
 * Channel CREATION is gated on the workflow being live + the caller
 * being a legitimate party. SENDING is gated only on `channel.status`
 * (the lifecycle cron is the sole closer, so the 30-day grace = a
 * window of continued wrap-up messaging) plus block / access-policy /
 * rate-limit. The room is never derived from caller input.
 */
@Injectable()
export class DmService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
    private readonly analytics: AnalyticsService,
    private readonly rateLimit: RateLimitService,
    private readonly blockMute: BlockMuteService,
    private readonly notifications: NotificationService,
    private readonly autoMod: AutoModerationService,
  ) {}

  // ---- Channel resolve / create ---------------------------------------

  async resolveOrCreateChannel(
    input: CreateDmChannelInput,
    viewer: Viewer & { id: string },
  ): Promise<DmChannelDTO> {
    const scope = (input.scope ?? '').toUpperCase();
    if (!VALID_SCOPES.includes(scope)) {
      throw new BadRequestException(`Invalid scope: ${input.scope}`);
    }
    if (!input.ref_id) {
      throw new BadRequestException('ref_id is required');
    }

    const resolved =
      scope === 'RECRUITMENT'
        ? await this._resolveRecruitment(input, viewer)
        : await this._resolveContribution(input, viewer);

    // Access-policy gate: the caller must currently be allowed the
    // workflow's space policy (a demoted planner loses PLANNER_ONLY).
    if (
      !this.access
        .accessPoliciesAllowedFor(viewer)
        .includes(resolved.spaceAccessPolicy)
    ) {
      throw new NotFoundException('Workflow not found');
    }

    const channel = await this.prisma.dmChannel.upsert({
      where: {
        scope_refId_partyAId: {
          scope,
          refId: input.ref_id,
          partyAId: resolved.partyAId,
        },
      },
      create: {
        scope,
        refId: input.ref_id,
        partyAId: resolved.partyAId,
        partyBId: resolved.partyBId,
        spaceAccessPolicy: resolved.spaceAccessPolicy,
      },
      update: {},
      include: {
        partyA: { include: { profile: true } },
        partyB: { include: { profile: true } },
      },
    });

    this.analytics.record({
      actorId: viewer.id,
      eventType: 'DM_CHANNEL_CREATED',
      payload: { channel_id: channel.id, scope },
    });
    return this._toChannelDTO(channel as ChannelWithParties, viewer.id, false);
  }

  private async _resolveRecruitment(
    input: CreateDmChannelInput,
    viewer: Viewer & { id: string },
  ): Promise<{ partyAId: string; partyBId: string; spaceAccessPolicy: string }> {
    const post = await this.prisma.post.findUnique({
      where: { id: input.ref_id },
      include: {
        room: { include: { category: { include: { space: true } } } },
        recruitment: true,
      },
    });
    if (
      !post ||
      post.status === 'DELETED' ||
      post.status === 'HIDDEN' ||
      post.recruitment == null
    ) {
      throw new NotFoundException('Recruitment post not found');
    }
    const authorId = post.authorId;
    const applicantId =
      viewer.id === authorId ? input.counterpart_id : viewer.id;
    if (!applicantId) {
      throw new BadRequestException(
        'counterpart_id is required when the author opens a channel',
      );
    }
    if (viewer.id !== authorId && viewer.id !== applicantId) {
      throw new ForbiddenException('Not a party to this recruitment');
    }
    // An active application must exist for (post, applicant).
    const app = await this.prisma.recruitmentApplication.findUnique({
      where: {
        postId_applicantId: { postId: input.ref_id, applicantId },
      },
      select: { status: true },
    });
    if (!app || (app.status !== 'PENDING' && app.status !== 'ACCEPTED')) {
      throw new ForbiddenException('No active application for this post');
    }
    // Recruitment must still be live. The author-facing canonical status
    // lives in the legacy `recruitmentFields` JSON (the structured
    // `recruitment_posts.status` is NOT written on manual close).
    const legacy = post.recruitmentFields as { status?: string } | null;
    const status = legacy?.status ?? post.recruitment.status ?? 'OPEN';
    if (status !== 'OPEN' && status !== 'FILLED') {
      throw new ConflictException('Recruitment is closed');
    }
    return {
      partyAId: applicantId,
      partyBId: authorId,
      spaceAccessPolicy: post.room.category.space.accessPolicy,
    };
  }

  private async _resolveContribution(
    input: CreateDmChannelInput,
    viewer: Viewer & { id: string },
  ): Promise<{ partyAId: string; partyBId: string; spaceAccessPolicy: string }> {
    const c = await this.prisma.knowledgeContribution.findUnique({
      where: { id: input.ref_id },
      include: { hub: { include: { category: { include: { space: true } } } } },
    });
    if (!c) throw new NotFoundException('Contribution not found');
    if (c.status !== 'NEEDS_CHANGES' || !c.resolvedBy) {
      throw new ConflictException(
        'Contribution is not awaiting revisions',
      );
    }
    const proposerId = c.contributorId;
    const curatorId = c.resolvedBy;
    if (viewer.id !== proposerId && viewer.id !== curatorId) {
      throw new ForbiddenException('Not a party to this contribution');
    }
    return {
      partyAId: proposerId,
      partyBId: curatorId,
      spaceAccessPolicy: c.hub.category.space.accessPolicy,
    };
  }

  // ---- Send -----------------------------------------------------------

  async send(
    channelId: string,
    viewer: Viewer & { id: string },
    rawBody: string,
  ): Promise<DmMessageDTO> {
    const body = (rawBody ?? '').trim();
    if (body.length === 0) throw new BadRequestException('body is required');
    if (body.length > BODY_MAX) {
      throw new BadRequestException(`body must be at most ${BODY_MAX} chars`);
    }

    const channel = await this.prisma.dmChannel.findUnique({
      where: { id: channelId },
    });
    if (!channel) throw new NotFoundException('Channel not found');
    const counterpartId = this._counterpartOrThrow(channel, viewer.id);
    if (channel.status !== 'OPEN') {
      throw new ConflictException('This conversation is closed');
    }
    if (
      !this.access
        .accessPoliciesAllowedFor(viewer)
        .includes(channel.spaceAccessPolicy)
    ) {
      throw new NotFoundException('Channel not found');
    }
    // Bidirectional block check (mirrors reply/mention write paths).
    await assertNotBlocked(this.blockMute, viewer.id, counterpartId);
    // DM rate limit: tighter cap + enforced day-1 (force).
    this.rateLimit.consumeOrThrow(
      { scope: 'dm.send', viewer, limitPerMin: DM_RATE_PER_MIN, force: true },
      '메시지를 너무 빨리 보내고 있어요. 잠시 후 다시 시도해주세요.',
    );

    // P6.9 dup-spam gate (enforced day-1). A hidden message still
    // persists (the sender sees it as a placeholder) but does not
    // surface to, or notify, the recipient.
    const mod = await this.autoMod.evaluateDmMessageBeforeCreate({
      viewer,
      channelId,
      body,
    });
    const msg = await this.prisma.dmMessage.create({
      data: {
        channelId,
        senderId: viewer.id,
        body,
        status: mod.hide ? 'HIDDEN' : 'VISIBLE',
        autoModerationReason: mod.reason,
      },
    });

    if (!mod.hide) {
      await this.prisma.dmChannel.update({
        where: { id: channelId },
        data: { lastMessageAt: msg.createdAt },
      });
      // Notify the recipient — grouped per channel so a burst collapses
      // into one inbox entry. spaceAccessPolicy + actorId let the
      // notification read-side filter hide it from a demoted/blocking
      // recipient.
      await this.notifications.createOrGroup({
        userId: counterpartId,
        type: 'DM_MESSAGE_RECEIVED',
        actorId: viewer.id,
        groupKey: `DM:${channelId}`,
        payload: {
          channelId,
          spaceAccessPolicy: channel.spaceAccessPolicy,
        },
      });
    }

    this.analytics.record({
      actorId: viewer.id,
      eventType: 'DM_MESSAGE_SENT',
      payload: { channel_id: channelId, hidden: mod.hide },
    });
    return this._toMessageDTO(msg, viewer.id);
  }

  // ---- Reads ----------------------------------------------------------

  async listChannels(
    viewer: Viewer & { id: string },
  ): Promise<DmChannelListDTO> {
    const rows = await this.prisma.dmChannel.findMany({
      where: { OR: [{ partyAId: viewer.id }, { partyBId: viewer.id }] },
      orderBy: { lastMessageAt: { sort: 'desc', nulls: 'last' } },
      include: {
        partyA: { include: { profile: true } },
        partyB: { include: { profile: true } },
      },
    });
    const allowed = this.access.accessPoliciesAllowedFor(viewer);
    const visible = rows.filter((r) => allowed.includes(r.spaceAccessPolicy));

    const ids = visible.map((r) => r.id);
    const unreadGroups = ids.length
      ? await this.prisma.dmMessage.groupBy({
          by: ['channelId'],
          where: {
            channelId: { in: ids },
            readByRecipientAt: null,
            status: 'VISIBLE',
            NOT: { senderId: viewer.id },
          },
          _count: true,
        })
      : [];
    const unreadByChannel = new Map(
      unreadGroups.map((g) => [g.channelId, g._count]),
    );

    return {
      items: visible.map((r) =>
        this._toChannelDTO(
          r as ChannelWithParties,
          viewer.id,
          (unreadByChannel.get(r.id) ?? 0) > 0,
        ),
      ),
    };
  }

  async listMessages(
    channelId: string,
    viewer: Viewer & { id: string },
    opts: { cursor?: string } = {},
  ): Promise<DmMessageListDTO> {
    const channel = await this.prisma.dmChannel.findUnique({
      where: { id: channelId },
    });
    if (!channel) throw new NotFoundException('Channel not found');
    this._counterpartOrThrow(channel, viewer.id);
    if (
      !this.access
        .accessPoliciesAllowedFor(viewer)
        .includes(channel.spaceAccessPolicy)
    ) {
      throw new NotFoundException('Channel not found');
    }

    const rows = await this.prisma.dmMessage.findMany({
      // Hide the counterpart's HIDDEN (moderated) messages; the sender
      // still sees their own as a placeholder.
      where: {
        channelId,
        OR: [{ status: 'VISIBLE' }, { senderId: viewer.id }],
      },
      orderBy: { createdAt: 'desc' },
      take: MESSAGES_PAGE + 1,
      ...(opts.cursor
        ? { cursor: { id: opts.cursor }, skip: 1 }
        : {}),
    });
    const hasMore = rows.length > MESSAGES_PAGE;
    const sliced = hasMore ? rows.slice(0, MESSAGES_PAGE) : rows;
    return {
      items: sliced.map((m) => this._toMessageDTO(m, viewer.id)),
      next_cursor: hasMore ? sliced[sliced.length - 1].id : null,
      channel_status: channel.status,
    };
  }

  async markRead(
    channelId: string,
    viewer: Viewer & { id: string },
  ): Promise<{ ok: boolean }> {
    const channel = await this.prisma.dmChannel.findUnique({
      where: { id: channelId },
    });
    if (!channel) throw new NotFoundException('Channel not found');
    this._counterpartOrThrow(channel, viewer.id);
    await this.prisma.dmMessage.updateMany({
      where: {
        channelId,
        readByRecipientAt: null,
        NOT: { senderId: viewer.id },
      },
      data: { readByRecipientAt: new Date() },
    });
    return { ok: true };
  }

  // ---- Helpers --------------------------------------------------------

  private _counterpartOrThrow(
    channel: { partyAId: string; partyBId: string },
    viewerId: string,
  ): string {
    if (viewerId === channel.partyAId) return channel.partyBId;
    if (viewerId === channel.partyBId) return channel.partyAId;
    throw new ForbiddenException('Not a party to this channel');
  }

  private _toChannelDTO(
    channel: ChannelWithParties,
    viewerId: string,
    unread: boolean,
  ): DmChannelDTO {
    const isA = channel.partyAId === viewerId;
    const counterpart = isA ? channel.partyB : channel.partyA;
    return {
      id: channel.id,
      scope: channel.scope,
      ref_id: channel.refId,
      counterpart: {
        id: counterpart.id,
        nickname: counterpart.profile?.nickname ?? null,
      },
      status: channel.status,
      last_message_at: channel.lastMessageAt?.toISOString() ?? null,
      unread,
      created_at: channel.createdAt.toISOString(),
    };
  }

  private _toMessageDTO(
    m: {
      id: string;
      channelId: string;
      senderId: string;
      body: string;
      status: string;
      createdAt: Date;
    },
    viewerId: string,
  ): DmMessageDTO {
    return {
      id: m.id,
      channel_id: m.channelId,
      sender_id: m.senderId,
      body: m.body,
      status: m.status,
      mine: m.senderId === viewerId,
      created_at: m.createdAt.toISOString(),
    };
  }
}
