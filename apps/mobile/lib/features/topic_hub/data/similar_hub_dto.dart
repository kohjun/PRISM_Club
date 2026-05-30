import '../../../core/json_helpers.dart';

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
    final hub = asMap(json, 'topic_hub') ?? const <String, dynamic>{};
    final reason = asMap(json, 'reason') ?? const <String, dynamic>{};
    return SimilarHubDto(
      id: asString(hub, 'id'),
      slug: asString(hub, 'slug'),
      title: asString(hub, 'title'),
      categorySlug: asString(hub, 'category_slug'),
      score: asDouble(json, 'score'),
      sharedContributorCount: asInt(reason, 'shared_contributor_count'),
      sharedRoomCount: asInt(reason, 'shared_room_count'),
    );
  }
}
