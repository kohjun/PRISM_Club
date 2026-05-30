import '../../../core/json_helpers.dart';

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
    final space = asMap(json, 'space') ?? const {};
    return CategoryDto(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: asStringOrNull(json, 'description'),
      spaceSlug: asString(space, 'slug'),
      spaceName: asString(space, 'name'),
    );
  }
}
