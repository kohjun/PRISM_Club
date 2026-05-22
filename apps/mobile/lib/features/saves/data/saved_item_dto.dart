import '../../event_card/data/event_card_dto.dart';
import '../../post/data/post_dto.dart';
import '../../reference/data/reference_dto.dart';

class SavedItemDto {
  const SavedItemDto({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.savedAt,
    this.collectionId,
    this.postTarget,
    this.referenceTarget,
    this.eventCardTarget,
  });

  final String id;
  final String targetType;
  final String targetId;
  final DateTime savedAt;
  final String? collectionId;
  final PostDto? postTarget;
  final ReferenceDto? referenceTarget;
  final EventCardDto? eventCardTarget;

  factory SavedItemDto.fromJson(Map<String, dynamic> json) {
    final type = json['target_type'] as String;
    final targetRaw = json['target'];
    final targetMap = targetRaw is Map ? targetRaw.cast<String, dynamic>() : null;

    PostDto? postTarget;
    ReferenceDto? referenceTarget;
    EventCardDto? eventCardTarget;

    if (targetMap != null) {
      if (type == 'POST') {
        // Server may return a full PostDTO shape or a flat preview (body_preview).
        // Attempt full parse; fall back to null so the caller can skip gracefully.
        try {
          postTarget = PostDto.fromJson(targetMap);
        } catch (_) {
          postTarget = null;
        }
      } else if (type == 'REFERENCE') {
        referenceTarget = ReferenceDto.fromJson(targetMap);
      } else if (type == 'EVENT_CARD') {
        eventCardTarget = EventCardDto.fromJson(targetMap);
      }
    }

    return SavedItemDto(
      id: json['id'] as String,
      targetType: type,
      targetId: json['target_id'] as String,
      savedAt: DateTime.parse(json['saved_at'] as String),
      collectionId: json['collection_id'] as String?,
      postTarget: postTarget,
      referenceTarget: referenceTarget,
      eventCardTarget: eventCardTarget,
    );
  }
}

class SavedCollectionDto {
  const SavedCollectionDto({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.itemCount,
  });

  final String id;
  final String name;
  final int sortOrder;
  final int itemCount;

  factory SavedCollectionDto.fromJson(Map<String, dynamic> json) =>
      SavedCollectionDto(
        id: json['id'] as String,
        name: json['name'] as String,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      );
}

class SavedItemListDto {
  const SavedItemListDto({required this.items});
  final List<SavedItemDto> items;

  factory SavedItemListDto.fromJson(Map<String, dynamic> json) => SavedItemListDto(
        items: (json['items'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(SavedItemDto.fromJson)
            .toList(growable: false),
      );
}

class ToggleSaveResultDto {
  const ToggleSaveResultDto({required this.saved});
  final bool saved;

  factory ToggleSaveResultDto.fromJson(Map<String, dynamic> json) =>
      ToggleSaveResultDto(saved: json['saved'] as bool? ?? false);
}
