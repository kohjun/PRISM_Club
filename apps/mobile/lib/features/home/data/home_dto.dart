import '../../event_card/data/event_card_dto.dart';
import '../../post/data/post_dto.dart';
import '../../room/data/room_summary_dto.dart';
import '../../saves/data/saved_item_dto.dart';

class TopicHubSummaryDto {
  const TopicHubSummaryDto({
    required this.id,
    required this.categorySlug,
    required this.title,
    required this.summary,
    required this.blockCount,
    required this.updatedAt,
  });

  final String id;
  final String categorySlug;
  final String title;
  final String? summary;
  final int blockCount;
  final DateTime updatedAt;

  factory TopicHubSummaryDto.fromJson(Map<String, dynamic> json) =>
      TopicHubSummaryDto(
        id: json['id'] as String,
        categorySlug: json['category_slug'] as String,
        title: json['title'] as String,
        summary: json['summary'] as String?,
        blockCount: json['block_count'] as int? ?? 0,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class HomeBundleDto {
  const HomeBundleDto({
    required this.unreadNotificationCount,
    required this.followedRoomUpdates,
    required this.recommendedRooms,
    required this.recommendedEvents,
    required this.trendingPosts,
    required this.activeTopicHubs,
    required this.savedRecently,
  });

  final int unreadNotificationCount;
  final List<PostDto> followedRoomUpdates;
  final List<RoomSummaryDto> recommendedRooms;
  final List<EventCardDto> recommendedEvents;
  final List<PostDto> trendingPosts;
  final List<TopicHubSummaryDto> activeTopicHubs;
  final List<SavedItemDto> savedRecently;

  factory HomeBundleDto.fromJson(Map<String, dynamic> json) => HomeBundleDto(
        unreadNotificationCount:
            json['unread_notification_count'] as int? ?? 0,
        followedRoomUpdates: (json['followed_room_updates'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(PostDto.fromJson)
            .toList(growable: false),
        recommendedRooms: (json['recommended_rooms'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(RoomSummaryDto.fromJson)
            .toList(growable: false),
        recommendedEvents: (json['recommended_events'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(EventCardDto.fromJson)
            .toList(growable: false),
        trendingPosts: (json['trending_posts'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(PostDto.fromJson)
            .toList(growable: false),
        activeTopicHubs: (json['active_topic_hubs'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(TopicHubSummaryDto.fromJson)
            .toList(growable: false),
        savedRecently: (json['saved_recently'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(SavedItemDto.fromJson)
            .toList(growable: false),
      );
}

class HomeFeedItemDto {
  const HomeFeedItemDto({
    required this.id,
    required this.type,
    required this.reason,
    required this.payload,
  });

  final String id;
  final String type;
  final String reason;
  final Map<String, dynamic> payload;

  factory HomeFeedItemDto.fromJson(Map<String, dynamic> json) => HomeFeedItemDto(
        id: json['id'] as String,
        type: json['type'] as String,
        reason: json['reason'] as String,
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

class HomeFeedPageDto {
  const HomeFeedPageDto({required this.items, required this.nextCursor});

  final List<HomeFeedItemDto> items;
  final String? nextCursor;

  factory HomeFeedPageDto.fromJson(Map<String, dynamic> json) => HomeFeedPageDto(
        items: (json['items'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(HomeFeedItemDto.fromJson)
            .toList(growable: false),
        nextCursor: json['next_cursor'] as String?,
      );
}
