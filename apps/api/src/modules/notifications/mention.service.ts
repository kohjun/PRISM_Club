import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { AnalyticsService } from '../analytics/analytics.service';

/**
 * Hard cap on how many notifications a single post/reply can fan out.
 * Defense against accidental "@everyone room"-style spam — a malicious
 * payload of 200 @-names should not produce 200 notifications.
 */
const MAX_MENTIONS_PER_SOURCE = 20;

// Korean + Latin + digits + underscore, 2–20 chars to match the
// Profile.nickname validation rules.
const MENTION_REGEX = /@([가-힣a-zA-Z0-9_]{2,20})/g;

export interface MentionInput {
  sourceType: 'POST' | 'REPLY';
  sourceId: string;
  authorId: string;
  body: string;
  /** Access policy of the surrounding post/reply's room. PLANNER_ONLY
   *  posts must not surface as a notification to a plain MEMBER even
   *  if their nickname appears in the body. */
  spaceAccessPolicy: string;
  /** Extra hop the notification surface needs to deep-link back to. */
  notificationPayloadExtras?: Record<string, unknown>;
}

/**
 * P6.1 mention parser + notifier.
 *
 * Called from PostService.create() and ReplyService.create() AFTER the
 * row commits. Failures are logged but never propagated — a mention
 * fanout error must not block the underlying post write.
 *
 * The mentions table itself stores one row per distinct (source, user)
 * pair so PostService.delete() can cascade-clean without a body re-parse.
 */
@Injectable()
export class MentionService {
  private readonly log = new Logger(MentionService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly analytics: AnalyticsService,
  ) {}

  /**
   * Synchronous extract of nicknames from a body. Exposed for testing +
   * for the composer-side preview ("이런 사람들이 알림을 받아요").
   */
  extractNicknames(body: string): string[] {
    if (!body) return [];
    const seen = new Set<string>();
    const out: string[] = [];
    for (const m of body.matchAll(MENTION_REGEX)) {
      const nick = m[1];
      if (!nick) continue;
      if (seen.has(nick)) continue;
      seen.add(nick);
      out.push(nick);
      if (out.length >= MAX_MENTIONS_PER_SOURCE) break;
    }
    return out;
  }

  /**
   * Parse @nicknames from `body`, resolve to user ids (skipping self,
   * unknown, and blocked), then upsert mentions + fan out notifications.
   *
   * Returns the count of notifications written (0 on no-op / failure).
   */
  async recordMentions(input: MentionInput): Promise<number> {
    try {
      const nicks = this.extractNicknames(input.body);
      if (nicks.length === 0) return 0;

      // Lookup users by nickname. We join Profile because that's where
      // nickname lives — uniqueness on Profile.nickname is enforced at
      // the schema layer so a lookup returns at most one row per nick.
      const profiles = await this.prisma.profile.findMany({
        where: { nickname: { in: nicks } },
        select: { userId: true, nickname: true },
      });
      const recipients = profiles
        .map((p) => ({ id: p.userId, nickname: p.nickname }))
        .filter((p) => p.id !== input.authorId);
      if (recipients.length === 0) return 0;

      // P6.2 will plug a Block / Mute filter in here. Until that lands
      // we mention freely; the access-policy gate below is the only
      // visibility guard.

      // Insert mention rows. Use createMany with skipDuplicates so a
      // re-save of the same body (edit → re-save) is idempotent.
      await this.prisma.mention.createMany({
        data: recipients.map((r) => ({
          sourceType: input.sourceType,
          sourceId: input.sourceId,
          mentionedUserId: r.id,
          actorId: input.authorId,
        })),
        skipDuplicates: true,
      });

      // Build notification rows. We rely on the existing
      // NotificationService.listForUser read-time filter
      // (`payload.spaceAccessPolicy` vs viewer roles, see
      // notification.service.ts:92-97) instead of pre-filtering by role
      // here — a recipient's role membership can change over the
      // notification's lifetime and the read-side check is the canonical
      // gate. We simply stamp the policy so the filter has something
      // to compare against.
      const notifs = recipients.map((r) => ({
        userId: r.id,
        type:
          input.sourceType === 'POST'
            ? 'MENTIONED_IN_POST'
            : 'MENTIONED_IN_REPLY',
        payload: {
          actorId: input.authorId,
          mentionedNickname: r.nickname,
          sourceType: input.sourceType,
          sourceId: input.sourceId,
          spaceAccessPolicy: input.spaceAccessPolicy,
          ...(input.notificationPayloadExtras ?? {}),
        },
      }));

      await this.prisma.notification.createMany({ data: notifs });

      this.analytics.record({
        actorId: input.authorId,
        eventType: 'USER_MENTIONED',
        payload: {
          source_type: input.sourceType,
          source_id: input.sourceId,
          recipients: notifs.length,
        },
      });

      return notifs.length;
    } catch (e) {
      this.log.warn(
        `mention fanout failed for ${input.sourceType}=${input.sourceId}: ${e instanceof Error ? e.message : String(e)}`,
      );
      return 0;
    }
  }

  /**
   * Cleanup hook for the post / reply hard-delete paths. Cascade FK
   * already handles user-delete; this is for the source row going
   * away while users live.
   */
  async clearForSource(
    sourceType: 'POST' | 'REPLY',
    sourceId: string,
  ): Promise<void> {
    await this.prisma.mention.deleteMany({
      where: { sourceType, sourceId },
    });
  }
}
