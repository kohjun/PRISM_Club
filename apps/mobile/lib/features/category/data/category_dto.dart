class CategoryDto {
  const CategoryDto({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.spaceSlug,
    required this.spaceName,
  });

  final String id;
  final String slug;
  final String name;
  final String? description;
  final String spaceSlug;
  final String spaceName;

  factory CategoryDto.fromJson(Map<String, dynamic> json) {
    final space = (json['space'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CategoryDto(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      spaceSlug: (space['slug'] as String?) ?? '',
      spaceName: (space['name'] as String?) ?? '',
    );
  }
}
