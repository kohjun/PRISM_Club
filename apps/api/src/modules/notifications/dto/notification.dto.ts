export interface NotificationDTO {
  id: string;
  type: string;
  is_read: boolean;
  payload: Record<string, unknown>;
  /**
   * P6.3 grouping: ISO timestamp of the latest actor merged into the
   * row. Equal to `created_at` for ungrouped rows. Mobile sorts by
   * `updated_at` so a freshly-grouped row pops back to the top.
   */
  updated_at: string;
  created_at: string;
}

export interface NotificationListDTO {
  items: NotificationDTO[];
  next_cursor: string | null;
  unread_count: number;
}

export interface UnreadCountDTO {
  count: number;
}

export interface NotificationPreferencesDTO {
  pref_reply_on_post: boolean;
  pref_nested_reply: boolean;
  pref_new_post_in_followed_room: boolean;
  pref_recruitment_status_changed: boolean;
  pref_contribution_resolved: boolean;
  pref_push_enabled: boolean;
  pref_email_enabled: boolean;
  weekly_digest_enabled: boolean;
  updated_at: string;
}

export interface DeviceTokenDTO {
  id: string;
  provider: string;
  platform: string;
  app_version: string | null;
  device_model: string | null;
  locale: string | null;
  last_seen_at: string;
}
