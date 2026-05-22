class NotificationDto {
  const NotificationDto({
    required this.id,
    required this.type,
    required this.isRead,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String type;
  final bool isRead;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  factory NotificationDto.fromJson(Map<String, dynamic> json) => NotificationDto(
        id: json['id'] as String,
        type: json['type'] as String,
        isRead: json['is_read'] as bool? ?? false,
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? {},
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Per-user notification preferences mirror. Maps 1:1 to the API DTO
/// (snake_case in JSON, camelCase here). Server lazy-creates the row on
/// first GET so the response always populates every field.
class NotificationPreferencesDto {
  const NotificationPreferencesDto({
    required this.prefReplyOnPost,
    required this.prefNestedReply,
    required this.prefNewPostInFollowedRoom,
    required this.prefRecruitmentStatusChanged,
    required this.prefContributionResolved,
    required this.prefPushEnabled,
    required this.prefEmailEnabled,
  });

  final bool prefReplyOnPost;
  final bool prefNestedReply;
  final bool prefNewPostInFollowedRoom;
  final bool prefRecruitmentStatusChanged;
  final bool prefContributionResolved;
  final bool prefPushEnabled;
  final bool prefEmailEnabled;

  factory NotificationPreferencesDto.fromJson(Map<String, dynamic> json) =>
      NotificationPreferencesDto(
        prefReplyOnPost: json['pref_reply_on_post'] as bool? ?? true,
        prefNestedReply: json['pref_nested_reply'] as bool? ?? true,
        prefNewPostInFollowedRoom:
            json['pref_new_post_in_followed_room'] as bool? ?? true,
        prefRecruitmentStatusChanged:
            json['pref_recruitment_status_changed'] as bool? ?? true,
        prefContributionResolved:
            json['pref_contribution_resolved'] as bool? ?? true,
        prefPushEnabled: json['pref_push_enabled'] as bool? ?? true,
        prefEmailEnabled: json['pref_email_enabled'] as bool? ?? true,
      );

  NotificationPreferencesDto copyWith({
    bool? prefReplyOnPost,
    bool? prefNestedReply,
    bool? prefNewPostInFollowedRoom,
    bool? prefRecruitmentStatusChanged,
    bool? prefContributionResolved,
    bool? prefPushEnabled,
    bool? prefEmailEnabled,
  }) =>
      NotificationPreferencesDto(
        prefReplyOnPost: prefReplyOnPost ?? this.prefReplyOnPost,
        prefNestedReply: prefNestedReply ?? this.prefNestedReply,
        prefNewPostInFollowedRoom:
            prefNewPostInFollowedRoom ?? this.prefNewPostInFollowedRoom,
        prefRecruitmentStatusChanged:
            prefRecruitmentStatusChanged ?? this.prefRecruitmentStatusChanged,
        prefContributionResolved:
            prefContributionResolved ?? this.prefContributionResolved,
        prefPushEnabled: prefPushEnabled ?? this.prefPushEnabled,
        prefEmailEnabled: prefEmailEnabled ?? this.prefEmailEnabled,
      );
}

class NotificationListDto {
  const NotificationListDto({
    required this.items,
    required this.nextCursor,
    required this.unreadCount,
  });

  final List<NotificationDto> items;
  final String? nextCursor;
  final int unreadCount;

  factory NotificationListDto.fromJson(Map<String, dynamic> json) =>
      NotificationListDto(
        items: (json['items'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(NotificationDto.fromJson)
            .toList(growable: false),
        nextCursor: json['next_cursor'] as String?,
        unreadCount: json['unread_count'] as int? ?? 0,
      );
}
