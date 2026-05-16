import '../../event_card/data/event_card_dto.dart';
import '../../reference/data/reference_dto.dart';

/// A pin's `target` is either an EventCard or a Reference (per `target_type`).
class RoomPinDto {
  const RoomPinDto({
    required this.id,
    required this.targetType,
    required this.target,
    required this.sortOrder,
  });

  final String id;
  final String targetType; // EVENT_CARD | REFERENCE
  final Object target;
  final int sortOrder;

  EventCardDto? get asEventCard =>
      target is EventCardDto ? target as EventCardDto : null;
  ReferenceDto? get asReference =>
      target is ReferenceDto ? target as ReferenceDto : null;

  factory RoomPinDto.fromJson(Map<String, dynamic> json) {
    final type = json['target_type'] as String;
    final targetMap = (json['target'] as Map).cast<String, dynamic>();
    final Object target = type == 'EVENT_CARD'
        ? EventCardDto.fromJson(targetMap)
        : ReferenceDto.fromJson(targetMap);
    return RoomPinDto(
      id: json['id'] as String,
      targetType: type,
      target: target,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}
