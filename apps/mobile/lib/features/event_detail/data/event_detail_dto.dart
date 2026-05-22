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

class RsvpStateDto {
  const RsvpStateDto({
    required this.myStatus,
    required this.interestedCount,
    required this.goingCount,
    required this.attendedCount,
  });

  /// null when no RSVP exists yet.
  final String? myStatus;
  final int interestedCount;
  final int goingCount;
  final int attendedCount;

  static const empty = RsvpStateDto(
    myStatus: null,
    interestedCount: 0,
    goingCount: 0,
    attendedCount: 0,
  );

  factory RsvpStateDto.fromJson(Map<String, dynamic> json) {
    final counts = (json['counts'] as Map?)?.cast<String, dynamic>() ?? const {};
    return RsvpStateDto(
      myStatus: json['my_status'] as String?,
      interestedCount: counts['interested'] as int? ?? 0,
      goingCount: counts['going'] as int? ?? 0,
      attendedCount: counts['attended'] as int? ?? 0,
    );
  }
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
    required this.rsvp,
  });

  final EventCardDto eventCard;
  final List<RelatedRoomDto> relatedRooms;
  final List<PostDto> relatedPosts;
  final String? relatedPostsNextCursor;
  final String? defaultComposeRoomSlug;
  final int postCount;
  final int roomCount;
  final RsvpStateDto rsvp;

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
    final rsvpRaw = json['rsvp'];
    final rsvp = rsvpRaw is Map
        ? RsvpStateDto.fromJson(rsvpRaw.cast<String, dynamic>())
        : RsvpStateDto.empty;
    return EventDetailBundleDto(
      eventCard: card,
      relatedRooms: rooms,
      relatedPosts: posts,
      relatedPostsNextCursor: relatedPostsRaw['next_cursor'] as String?,
      defaultComposeRoomSlug: json['default_compose_room_slug'] as String?,
      postCount: counts['post_count'] as int? ?? 0,
      roomCount: counts['room_count'] as int? ?? 0,
      rsvp: rsvp,
    );
  }
}
