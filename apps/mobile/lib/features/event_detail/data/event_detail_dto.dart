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

class EventReviewDto {
  const EventReviewDto({
    required this.id,
    required this.userId,
    required this.userNickname,
    required this.rating,
    required this.body,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? userNickname;
  final int rating;
  final String body;
  final String status;
  final DateTime createdAt;

  factory EventReviewDto.fromJson(Map<String, dynamic> j) {
    final user = (j['user'] as Map).cast<String, dynamic>();
    return EventReviewDto(
      id: j['id'] as String,
      userId: user['id'] as String,
      userNickname: user['nickname'] as String?,
      rating: j['rating'] as int,
      body: j['body'] as String,
      status: j['status'] as String? ?? 'VISIBLE',
      createdAt: DateTime.parse(j['created_at'] as String),
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
    required this.verifiedReviews,
    required this.reviewCount,
    required this.reviewAverage,
  });

  final EventCardDto eventCard;
  final List<RelatedRoomDto> relatedRooms;
  final List<PostDto> relatedPosts;
  final String? relatedPostsNextCursor;
  final String? defaultComposeRoomSlug;
  final int postCount;
  final int roomCount;
  final RsvpStateDto rsvp;
  final List<EventReviewDto> verifiedReviews;
  final int reviewCount;
  final double? reviewAverage;

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
    final reviews = (json['verified_reviews'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(EventReviewDto.fromJson)
        .toList(growable: false);
    final avgRaw = counts['review_average'];
    return EventDetailBundleDto(
      eventCard: card,
      relatedRooms: rooms,
      relatedPosts: posts,
      relatedPostsNextCursor: relatedPostsRaw['next_cursor'] as String?,
      defaultComposeRoomSlug: json['default_compose_room_slug'] as String?,
      postCount: counts['post_count'] as int? ?? 0,
      roomCount: counts['room_count'] as int? ?? 0,
      rsvp: rsvp,
      verifiedReviews: reviews,
      reviewCount: counts['review_count'] as int? ?? 0,
      reviewAverage: avgRaw is num ? avgRaw.toDouble() : null,
    );
  }
}
