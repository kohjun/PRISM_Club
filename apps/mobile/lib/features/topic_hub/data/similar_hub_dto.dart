/// Response from `GET /v1/topic-hubs/:slug/similar`. Each entry pairs
/// a hub summary with the Jaccard score and a small "why" reason so
/// the strip card can render an explanation chip without a follow-up
/// fetch.
class SimilarHubDto {
  const SimilarHubDto({
    required this.id,
    required this.slug,
    required this.title,
    required this.categorySlug,
    required this.score,
    required this.sharedContributorCount,
    required this.sharedRoomCount,
  });

  final String id;
  final String slug;
  final String title;
  final String categorySlug;
  final double score;
  final int sharedContributorCount;
  final int sharedRoomCount;

  factory SimilarHubDto.fromJson(Map<String, dynamic> json) {
    final hub = (json['topic_hub'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final reason = (json['reason'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return SimilarHubDto(
      id: hub['id'] as String? ?? '',
      slug: hub['slug'] as String? ?? '',
      title: hub['title'] as String? ?? '',
      categorySlug: hub['category_slug'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      sharedContributorCount:
          (reason['shared_contributor_count'] as num?)?.toInt() ?? 0,
      sharedRoomCount: (reason['shared_room_count'] as num?)?.toInt() ?? 0,
    );
  }
}
