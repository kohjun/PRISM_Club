class SpaceDto {
  const SpaceDto({
    required this.id,
    required this.slug,
    required this.name,
    required this.audience,
    required this.accessPolicy,
  });

  final String id;
  final String slug;
  final String name;
  final String audience; // PARTICIPANT | PLANNER
  final String accessPolicy;

  bool get isPlanner => audience == 'PLANNER';

  factory SpaceDto.fromJson(Map<String, dynamic> json) => SpaceDto(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        audience: json['audience'] as String,
        accessPolicy: json['access_policy'] as String? ?? 'PUBLIC',
      );
}
