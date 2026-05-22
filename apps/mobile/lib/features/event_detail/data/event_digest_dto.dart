class EventDigestTopPostDto {
  const EventDigestTopPostDto({
    required this.id,
    required this.snippet,
    required this.roomSlug,
    required this.likeCount,
    required this.replyCount,
  });

  final String id;
  final String snippet;
  final String roomSlug;
  final int likeCount;
  final int replyCount;

  factory EventDigestTopPostDto.fromJson(Map<String, dynamic> j) =>
      EventDigestTopPostDto(
        id: j['id'] as String,
        snippet: j['snippet'] as String? ?? '',
        roomSlug: j['room_slug'] as String,
        likeCount: j['like_count'] as int? ?? 0,
        replyCount: j['reply_count'] as int? ?? 0,
      );
}

class EventDigestTopReviewDto {
  const EventDigestTopReviewDto({
    required this.id,
    required this.rating,
    required this.snippet,
    required this.userNickname,
  });

  final String id;
  final int rating;
  final String snippet;
  final String? userNickname;

  factory EventDigestTopReviewDto.fromJson(Map<String, dynamic> j) =>
      EventDigestTopReviewDto(
        id: j['id'] as String,
        rating: j['rating'] as int? ?? 0,
        snippet: j['snippet'] as String? ?? '',
        userNickname: j['user_nickname'] as String?,
      );
}

class EventDigestPayloadDto {
  const EventDigestPayloadDto({
    required this.topPosts,
    required this.topReviews,
    required this.reviewCount,
    required this.averageRating,
  });

  final List<EventDigestTopPostDto> topPosts;
  final List<EventDigestTopReviewDto> topReviews;
  final int reviewCount;
  final double? averageRating;

  bool get isEmpty => topPosts.isEmpty && topReviews.isEmpty;

  factory EventDigestPayloadDto.fromJson(Map<String, dynamic> j) {
    final avg = j['averageRating'];
    return EventDigestPayloadDto(
      topPosts: (j['topPosts'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(EventDigestTopPostDto.fromJson)
          .toList(growable: false),
      topReviews: (j['topReviews'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(EventDigestTopReviewDto.fromJson)
          .toList(growable: false),
      reviewCount: j['reviewCount'] as int? ?? 0,
      averageRating: avg is num ? avg.toDouble() : null,
    );
  }
}

class EventDigestDto {
  const EventDigestDto({
    required this.eventCardId,
    required this.payload,
  });

  final String eventCardId;
  final EventDigestPayloadDto payload;

  factory EventDigestDto.fromJson(Map<String, dynamic> j) => EventDigestDto(
        eventCardId: j['event_card_id'] as String,
        payload: EventDigestPayloadDto.fromJson(
          (j['payload'] as Map).cast<String, dynamic>(),
        ),
      );
}
