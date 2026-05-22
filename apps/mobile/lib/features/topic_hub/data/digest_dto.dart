class DigestRevisionDto {
  const DigestRevisionDto({
    required this.blockId,
    required this.version,
    required this.blockType,
    required this.title,
    required this.contributorNickname,
    required this.changedAt,
  });

  final String blockId;
  final int version;
  final String blockType;
  final String title;
  final String? contributorNickname;
  final DateTime changedAt;

  factory DigestRevisionDto.fromJson(Map<String, dynamic> j) =>
      DigestRevisionDto(
        blockId: j['block_id'] as String,
        version: j['version'] as int,
        blockType: j['block_type'] as String,
        title: j['title'] as String,
        contributorNickname: j['contributor_nickname'] as String?,
        changedAt: DateTime.parse(j['changed_at'] as String),
      );
}

class DigestReferenceDto {
  const DigestReferenceDto({
    required this.id,
    required this.title,
    required this.sourceTier,
    required this.sourceName,
    required this.url,
  });

  final String id;
  final String title;
  final String sourceTier;
  final String? sourceName;
  final String url;

  factory DigestReferenceDto.fromJson(Map<String, dynamic> j) =>
      DigestReferenceDto(
        id: j['id'] as String,
        title: j['title'] as String,
        sourceTier: j['source_tier'] as String? ?? 'UNKNOWN',
        sourceName: j['source_name'] as String?,
        url: j['url'] as String,
      );
}

class DigestEventDto {
  const DigestEventDto({
    required this.id,
    required this.title,
    required this.venueName,
    required this.region,
    required this.startsAt,
    required this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String venueName;
  final String region;
  final DateTime startsAt;
  final String? thumbnailUrl;

  factory DigestEventDto.fromJson(Map<String, dynamic> j) => DigestEventDto(
        id: j['id'] as String,
        title: j['title'] as String,
        venueName: j['venue_name'] as String,
        region: j['region'] as String,
        startsAt: DateTime.parse(j['starts_at'] as String),
        thumbnailUrl: j['thumbnail_url'] as String?,
      );
}

class DigestPostDto {
  const DigestPostDto({
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

  factory DigestPostDto.fromJson(Map<String, dynamic> j) => DigestPostDto(
        id: j['id'] as String,
        snippet: j['snippet'] as String? ?? '',
        roomSlug: j['room_slug'] as String,
        likeCount: j['like_count'] as int? ?? 0,
        replyCount: j['reply_count'] as int? ?? 0,
      );
}

class DigestPayloadDto {
  const DigestPayloadDto({
    required this.revisions,
    required this.newReferences,
    required this.newEvents,
    required this.popularPosts,
  });

  final List<DigestRevisionDto> revisions;
  final List<DigestReferenceDto> newReferences;
  final List<DigestEventDto> newEvents;
  final List<DigestPostDto> popularPosts;

  bool get isEmpty =>
      revisions.isEmpty &&
      newReferences.isEmpty &&
      newEvents.isEmpty &&
      popularPosts.isEmpty;

  factory DigestPayloadDto.fromJson(Map<String, dynamic> j) =>
      DigestPayloadDto(
        revisions: (j['revisions'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DigestRevisionDto.fromJson)
            .toList(growable: false),
        newReferences: (j['newReferences'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DigestReferenceDto.fromJson)
            .toList(growable: false),
        newEvents: (j['newEvents'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DigestEventDto.fromJson)
            .toList(growable: false),
        popularPosts: (j['popularPosts'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DigestPostDto.fromJson)
            .toList(growable: false),
      );
}

class DigestDto {
  const DigestDto({
    required this.topicHubId,
    required this.categorySlug,
    required this.periodStart,
    required this.periodEnd,
    required this.generatedAt,
    required this.payload,
  });

  final String topicHubId;
  final String categorySlug;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime generatedAt;
  final DigestPayloadDto payload;

  factory DigestDto.fromJson(Map<String, dynamic> j) => DigestDto(
        topicHubId: j['topic_hub_id'] as String,
        categorySlug: j['category_slug'] as String,
        periodStart: DateTime.parse(j['period_start'] as String),
        periodEnd: DateTime.parse(j['period_end'] as String),
        generatedAt: DateTime.parse(j['generated_at'] as String),
        payload: DigestPayloadDto.fromJson(
          (j['payload'] as Map).cast<String, dynamic>(),
        ),
      );
}
