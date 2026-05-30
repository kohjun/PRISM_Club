import '../../../core/json_helpers.dart';
import 'room_pin_dto.dart';

class RoomDetailDto {
  const RoomDetailDto({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.rules,
    required this.origin,
    required this.roomType,
    required this.ownerNickname,
    required this.pins,
    required this.postCount,
  });

  final String id;
  final String slug;
  final String name;
  final String? description;
  final String? rules;
  final String origin;
  final String roomType;
  final String? ownerNickname;
  final List<RoomPinDto> pins;
  final int postCount;

  factory RoomDetailDto.fromJson(Map<String, dynamic> json) {
    final ownerMap = asMap(json, 'owner');
    final counts = asMap(json, 'counts') ?? const {};
    return RoomDetailDto(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: asStringOrNull(json, 'description'),
      rules: asStringOrNull(json, 'rules'),
      origin: json['origin'] as String,
      roomType: json['room_type'] as String,
      ownerNickname: ownerMap?['nickname'] as String?,
      pins: (json['pins'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(RoomPinDto.fromJson)
          .toList(growable: false),
      postCount: asInt(counts, 'post_count'),
    );
  }
}
