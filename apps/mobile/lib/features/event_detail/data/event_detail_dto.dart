import '../../event_card/data/event_card_dto.dart';
import '../../post/data/post_dto.dart';

class RelatedRoomDto {
  const RelatedRoomDto({
    required this.id,
    required this.slug,
    required this.name,
    required this.origin,
    required this.roomType,
    required this.ownerNickname,
    required this.relation,
  });

  final String id;
  final String slug;
  final String name;
  final String origin; // OFFICIAL | USER
  final String roomType;
  final String? ownerNickname;
  final String relation; // PIN | POST_ATTACHMENT

  factory RelatedRoomDto.fromJson(Map<String, dynamic> json) => RelatedRoomDto(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        origin: json['origin'] as String,
        roomType: json['room_type'] as String,
        ownerNickname: json['owner_nickname'] as String?,
        relation: json['relation'] as String? ?? 'PIN',
      );
}

class EventDetailBundleDto {
  const EventDetailBundleDto({
    required this.eventCard,
    required this.relatedRooms,
    required this.relatedPosts,
    required this.relatedPostsNextCursor,
    required this.defaultComposeRoomSlug,
    required this.postCount,
    required this.roomCount,
  });

  final EventCardDto eventCard;
  final List<RelatedRoomDto> relatedRooms;
  final List<PostDto> relatedPosts;
  final String? relatedPostsNextCursor;
  final String? defaultComposeRoomSlug;
  final int postCount;
  final int roomCount;

  factory EventDetailBundleDto.fromJson(Map<String, dynamic> json) {
    final card = EventCardDto.fromJson(
      (json['event_card'] as Map).cast<String, dynamic>(),
    );
    final rooms = (json['related_rooms'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(RelatedRoomDto.fromJson)
        .toList(growable: false);
    final relatedPostsRaw =
        (json['related_posts'] as Map).cast<String, dynamic>();
    final posts = (relatedPostsRaw['items'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(PostDto.fromJson)
        .toList(growable: false);
    final counts = (json['counts'] as Map).cast<String, dynamic>();
    return EventDetailBundleDto(
      eventCard: card,
      relatedRooms: rooms,
      relatedPosts: posts,
      relatedPostsNextCursor: relatedPostsRaw['next_cursor'] as String?,
      defaultComposeRoomSlug: json['default_compose_room_slug'] as String?,
      postCount: counts['post_count'] as int? ?? 0,
      roomCount: counts['room_count'] as int? ?? 0,
    );
  }
}
