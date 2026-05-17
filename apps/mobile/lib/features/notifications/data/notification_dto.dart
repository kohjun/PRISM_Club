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
