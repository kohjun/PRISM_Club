import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../shared/prisma.service';
import { NotificationPreferencesDTO } from './dto/notification.dto';

/**
 * Per-user notification preferences (P1.2).
 *
 * The DB row is lazy-created — an absent row means "all defaults true" so
 * existing seed users keep receiving notifications until they explicitly
 * toggle anything. The push delivery layer queries `pushEnabledFor(user, type)`
 * to short-circuit fan-out cheaply.
 */
@Injectable()
export class NotificationPreferencesService {
  constructor(private readonly prisma: PrismaService) {}

  async get(userId: string): Promise<NotificationPreferencesDTO> {
    const row = await this.prisma.notificationPreference.upsert({
      where: { userId },
      update: {},
      create: { userId },
    });
    return this.toDTO(row);
  }

  async update(
    userId: string,
    input: Partial<{
      pref_reply_on_post: boolean;
      pref_nested_reply: boolean;
      pref_new_post_in_followed_room: boolean;
      pref_recruitment_status_changed: boolean;
      pref_contribution_resolved: boolean;
      pref_push_enabled: boolean;
      pref_email_enabled: boolean;
    }>,
  ): Promise<NotificationPreferencesDTO> {
    const data: Record<string, boolean> = {};
    if (typeof input.pref_reply_on_post === 'boolean')
      data.prefReplyOnPost = input.pref_reply_on_post;
    if (typeof input.pref_nested_reply === 'boolean')
      data.prefNestedReply = input.pref_nested_reply;
    if (typeof input.pref_new_post_in_followed_room === 'boolean')
      data.prefNewPostInFollowedRoom = input.pref_new_post_in_followed_room;
    if (typeof input.pref_recruitment_status_changed === 'boolean')
      data.prefRecruitmentStatusChanged = input.pref_recruitment_status_changed;
    if (typeof input.pref_contribution_resolved === 'boolean')
      data.prefContributionResolved = input.pref_contribution_resolved;
    if (typeof input.pref_push_enabled === 'boolean')
      data.prefPushEnabled = input.pref_push_enabled;
    if (typeof input.pref_email_enabled === 'boolean')
      data.prefEmailEnabled = input.pref_email_enabled;

    const row = await this.prisma.notificationPreference.upsert({
      where: { userId },
      update: data,
      create: { userId, ...data },
    });
    return this.toDTO(row);
  }

  /**
   * Cheap gate for PushDelivery — defaults to true when no preference row
   * exists. Returns `{ allow: false, reason }` so the deliverer can record
   * the skip reason consistently across channels.
   */
  async pushAllowedFor(
    userId: string,
    type: string,
  ): Promise<{ allow: boolean; reason?: string }> {
    const row = await this.prisma.notificationPreference.findUnique({
      where: { userId },
    });
    if (!row) return { allow: true };
    if (!row.prefPushEnabled) {
      return { allow: false, reason: 'user-pref-push-off' };
    }
    if (!this.typeEnabled(row, type)) {
      return { allow: false, reason: 'user-pref-type-off' };
    }
    return { allow: true };
  }

  private typeEnabled(
    row: {
      prefReplyOnPost: boolean;
      prefNestedReply: boolean;
      prefNewPostInFollowedRoom: boolean;
      prefRecruitmentStatusChanged: boolean;
      prefContributionResolved: boolean;
    },
    type: string,
  ): boolean {
    switch (type) {
      case 'REPLY_ON_POST':
        return row.prefReplyOnPost;
      case 'NESTED_REPLY':
        return row.prefNestedReply;
      case 'NEW_POST_IN_FOLLOWED_ROOM':
        return row.prefNewPostInFollowedRoom;
      case 'RECRUITMENT_STATUS_CHANGED':
        return row.prefRecruitmentStatusChanged;
      case 'CONTRIBUTION_RESOLVED':
        return row.prefContributionResolved;
      default:
        // Future types (EVENT_REMINDER, WEEKLY_DIGEST, ...) default to on
        // until they're surfaced in the settings UI.
        return true;
    }
  }

  private toDTO(row: {
    prefReplyOnPost: boolean;
    prefNestedReply: boolean;
    prefNewPostInFollowedRoom: boolean;
    prefRecruitmentStatusChanged: boolean;
    prefContributionResolved: boolean;
    prefPushEnabled: boolean;
    prefEmailEnabled: boolean;
    updatedAt: Date;
  }): NotificationPreferencesDTO {
    return {
      pref_reply_on_post: row.prefReplyOnPost,
      pref_nested_reply: row.prefNestedReply,
      pref_new_post_in_followed_room: row.prefNewPostInFollowedRoom,
      pref_recruitment_status_changed: row.prefRecruitmentStatusChanged,
      pref_contribution_resolved: row.prefContributionResolved,
      pref_push_enabled: row.prefPushEnabled,
      pref_email_enabled: row.prefEmailEnabled,
      updated_at: row.updatedAt.toISOString(),
    };
  }
}
