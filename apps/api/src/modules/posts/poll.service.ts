import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AccessControlService } from '../../shared/access-control.service';
import { AnalyticsService } from '../analytics/analytics.service';
import { RequestUser } from '../../shared/decorators/current-user.decorator';

const QUESTION_MAX = 200;
const LABEL_MAX = 80;
const MIN_OPTIONS = 2;
const MAX_OPTIONS = 6;

export interface CreatePollInput {
  question: string;
  options: string[];
  expires_at?: string | null;
  allow_multiple?: boolean;
}

export interface PollOptionDTO {
  id: string;
  label: string;
  sort_order: number;
  vote_count: number;
}

export interface PollDTO {
  id: string;
  question: string;
  expires_at: string | null;
  allow_multiple: boolean;
  status: 'OPEN' | 'CLOSED';
  options: PollOptionDTO[];
  total_votes: number;
  my_vote_option_ids: string[];
}

/**
 * P6.5 poll service.
 *
 * Polls are 1:1 with a Post — created inside PostService.create() and
 * cascade-deleted by Post FK. The service owns voting and vote
 * tabulation but never the post lifecycle.
 *
 * Single-choice polls reject a 2nd distinct vote with 409; the same
 * call with the same option_id is the "undo" path (DELETE). Multi-
 * choice polls accept any number of distinct options up to the option
 * count; the unique (poll, voter, option) catches duplicates.
 *
 * Expired polls (expires_at in the past) reject writes with 400 but
 * still serve reads.
 */
@Injectable()
export class PollService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly access: AccessControlService,
    private readonly analytics: AnalyticsService,
  ) {}

  /**
   * Validate + persist a poll alongside a post. Returns the freshly-
   * created poll id so the caller can include it in the post DTO
   * response. Throws BadRequest if input is malformed — caller's
   * transaction rolls back.
   */
  async createForPost(
    tx: Pick<PrismaService, 'poll' | 'pollOption'>,
    postId: string,
    input: CreatePollInput,
  ): Promise<string> {
    const question = (input.question ?? '').trim();
    if (!question || question.length > QUESTION_MAX) {
      throw new BadRequestException(
        `question must be 1..${QUESTION_MAX} chars`,
      );
    }
    const opts = (input.options ?? [])
      .map((o) => (o ?? '').trim())
      .filter((o) => o.length > 0);
    if (opts.length < MIN_OPTIONS || opts.length > MAX_OPTIONS) {
      throw new BadRequestException(
        `poll must have ${MIN_OPTIONS}..${MAX_OPTIONS} options`,
      );
    }
    if (opts.some((o) => o.length > LABEL_MAX)) {
      throw new BadRequestException(
        `each option must be at most ${LABEL_MAX} chars`,
      );
    }
    // Reject duplicate labels — would confuse the voter UI.
    if (new Set(opts).size !== opts.length) {
      throw new BadRequestException('poll options must be distinct');
    }

    let expiresAt: Date | null = null;
    if (input.expires_at) {
      const d = new Date(input.expires_at);
      if (Number.isNaN(d.getTime())) {
        throw new BadRequestException('expires_at must be a valid ISO date');
      }
      if (d.getTime() <= Date.now()) {
        throw new BadRequestException('expires_at must be in the future');
      }
      expiresAt = d;
    }

    const poll = await tx.poll.create({
      data: {
        postId,
        question,
        expiresAt,
        allowMultiple: !!input.allow_multiple,
      },
    });
    await tx.pollOption.createMany({
      data: opts.map((label, i) => ({
        pollId: poll.id,
        label,
        sortOrder: i,
      })),
    });
    return poll.id;
  }

  /**
   * Cast a vote. Idempotent: voting the same option twice is the
   * "remove vote" path (DELETE). Multi-choice polls allow voting on
   * multiple options; each call toggles ONE option.
   */
  async vote(
    pollId: string,
    optionId: string,
    viewer: RequestUser,
  ): Promise<PollDTO> {
    const poll = await this.prisma.poll.findUnique({
      where: { id: pollId },
      include: { options: true, post: { include: { room: true } } },
    });
    if (!poll) throw new NotFoundException(`Poll not found: ${pollId}`);
    await this.access.assertCanReadRoomBySlug(poll.post.room.slug, viewer);

    if (poll.status === 'CLOSED') {
      throw new BadRequestException('Poll is closed');
    }
    if (poll.expiresAt && poll.expiresAt.getTime() <= Date.now()) {
      throw new BadRequestException('Poll has expired');
    }

    const option = poll.options.find((o) => o.id === optionId);
    if (!option) {
      throw new NotFoundException(`Option not found: ${optionId}`);
    }

    const existingSameOption = await this.prisma.pollVote.findFirst({
      where: {
        pollId,
        voterId: viewer.id,
        optionId,
      },
    });

    await this.prisma.$transaction(async (tx) => {
      if (existingSameOption) {
        // Toggle off — remove this vote.
        await tx.pollVote.delete({ where: { id: existingSameOption.id } });
        return;
      }

      if (!poll.allowMultiple) {
        // Single-choice: drop any existing vote by this user on this
        // poll, regardless of option, before inserting the new one.
        await tx.pollVote.deleteMany({
          where: { pollId, voterId: viewer.id },
        });
      }

      try {
        await tx.pollVote.create({
          data: { pollId, optionId, voterId: viewer.id },
        });
      } catch (e) {
        if ((e as { code?: string }).code === 'P2002') {
          throw new ConflictException('Already voted for this option');
        }
        throw e;
      }
    });

    this.analytics.record({
      actorId: viewer.id,
      eventType: 'POLL_VOTED',
      payload: { poll_id: pollId, option_id: optionId },
    });

    return this.summarize(pollId, viewer.id);
  }

  async clearVotes(pollId: string, viewer: RequestUser): Promise<PollDTO> {
    const poll = await this.prisma.poll.findUnique({
      where: { id: pollId },
      include: { post: { include: { room: true } } },
    });
    if (!poll) throw new NotFoundException(`Poll not found: ${pollId}`);
    await this.access.assertCanReadRoomBySlug(poll.post.room.slug, viewer);

    await this.prisma.pollVote.deleteMany({
      where: { pollId, voterId: viewer.id },
    });
    return this.summarize(pollId, viewer.id);
  }

  async summarize(pollId: string, viewerId: string): Promise<PollDTO> {
    const poll = await this.prisma.poll.findUnique({
      where: { id: pollId },
      include: { options: { orderBy: { sortOrder: 'asc' } } },
    });
    if (!poll) throw new NotFoundException(`Poll not found: ${pollId}`);
    const optionIds = poll.options.map((o) => o.id);
    const [voteGroups, myVotes] = await Promise.all([
      this.prisma.pollVote.groupBy({
        by: ['optionId'],
        where: { pollId, optionId: { in: optionIds } },
        _count: { _all: true },
      }),
      this.prisma.pollVote.findMany({
        where: { pollId, voterId: viewerId },
        select: { optionId: true },
      }),
    ]);
    const counts = new Map<string, number>();
    for (const g of voteGroups) {
      counts.set(g.optionId, g._count._all);
    }
    let total = 0;
    const options: PollOptionDTO[] = poll.options.map((o) => {
      const c = counts.get(o.id) ?? 0;
      total += c;
      return {
        id: o.id,
        label: o.label,
        sort_order: o.sortOrder,
        vote_count: c,
      };
    });
    return {
      id: poll.id,
      question: poll.question,
      expires_at: poll.expiresAt?.toISOString() ?? null,
      allow_multiple: poll.allowMultiple,
      status: poll.status as 'OPEN' | 'CLOSED',
      options,
      total_votes: total,
      my_vote_option_ids: myVotes.map((v) => v.optionId),
    };
  }

  /**
   * Batch summary used by the timeline serializer. Returns map of
   * postId → PollDTO so the caller stays O(rows). Polls with no
   * sidecar are absent from the map.
   */
  async summarizeForPosts(
    postIds: string[],
    viewerId: string,
  ): Promise<Map<string, PollDTO>> {
    if (postIds.length === 0) return new Map();
    const polls = await this.prisma.poll.findMany({
      where: { postId: { in: postIds } },
      include: { options: { orderBy: { sortOrder: 'asc' } } },
    });
    if (polls.length === 0) return new Map();

    const allOptionIds = polls.flatMap((p) => p.options.map((o) => o.id));
    const [voteGroups, myVotes] = await Promise.all([
      this.prisma.pollVote.groupBy({
        by: ['optionId'],
        where: { optionId: { in: allOptionIds } },
        _count: { _all: true },
      }),
      this.prisma.pollVote.findMany({
        where: {
          pollId: { in: polls.map((p) => p.id) },
          voterId: viewerId,
        },
        select: { pollId: true, optionId: true },
      }),
    ]);
    const optionCounts = new Map<string, number>();
    for (const g of voteGroups) optionCounts.set(g.optionId, g._count._all);
    const myByPoll = new Map<string, string[]>();
    for (const v of myVotes) {
      const arr = myByPoll.get(v.pollId) ?? [];
      arr.push(v.optionId);
      myByPoll.set(v.pollId, arr);
    }

    const out = new Map<string, PollDTO>();
    for (const poll of polls) {
      let total = 0;
      const options: PollOptionDTO[] = poll.options.map((o) => {
        const c = optionCounts.get(o.id) ?? 0;
        total += c;
        return {
          id: o.id,
          label: o.label,
          sort_order: o.sortOrder,
          vote_count: c,
        };
      });
      out.set(poll.postId, {
        id: poll.id,
        question: poll.question,
        expires_at: poll.expiresAt?.toISOString() ?? null,
        allow_multiple: poll.allowMultiple,
        status: poll.status as 'OPEN' | 'CLOSED',
        options,
        total_votes: total,
        my_vote_option_ids: myByPoll.get(poll.id) ?? [],
      });
    }
    return out;
  }
}
