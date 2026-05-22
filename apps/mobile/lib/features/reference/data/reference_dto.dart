class ReferenceDto {
  const ReferenceDto({
    required this.id,
    required this.type,
    required this.url,
    required this.title,
    required this.sourceName,
    required this.thumbnailUrl,
    required this.summary,
    required this.status,
    required this.sourceTier,
  });

  final String id;
  final String type;
  final String url;
  final String title;
  final String? sourceName;
  final String? thumbnailUrl;
  final String? summary;
  final String status;

  /// P2.3 trust tier: OFFICIAL | TRUSTED | COMMUNITY | UNKNOWN.
  final String sourceTier;

  factory ReferenceDto.fromJson(Map<String, dynamic> json) => ReferenceDto(
        id: json['id'] as String,
        type: json['type'] as String,
        url: json['url'] as String,
        title: json['title'] as String,
        sourceName: json['source_name'] as String?,
        thumbnailUrl: json['thumbnail_url'] as String?,
        summary: json['summary'] as String?,
        status: json['status'] as String? ?? 'VISIBLE',
        sourceTier: json['source_tier'] as String? ?? 'UNKNOWN',
      );
}
