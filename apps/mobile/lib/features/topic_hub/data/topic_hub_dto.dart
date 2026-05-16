import '../../event_card/data/event_card_dto.dart';
import '../../reference/data/reference_dto.dart';
import '../../room/data/room_summary_dto.dart';

class KnowledgeBlockDto {
  const KnowledgeBlockDto({
    required this.id,
    required this.blockType,
    required this.title,
    required this.body,
    required this.sortOrder,
  });

  final String id;
  final String blockType;
  final String title;
  final String body;
  final int sortOrder;

  factory KnowledgeBlockDto.fromJson(Map<String, dynamic> json) => KnowledgeBlockDto(
        id: json['id'] as String,
        blockType: json['block_type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}

class TopicSignalDto {
  const TopicSignalDto({
    required this.id,
    required this.signalType,
    required this.title,
    required this.payload,
  });

  final String id;
  final String signalType;
  final String title;
  final Map<String, dynamic> payload;

  /// Convenience: produce a one-line display string from the payload.
  String get displayValue {
    if (payload.containsKey('text')) return payload['text'].toString();
    if (payload.containsKey('count')) return payload['count'].toString();
    return '';
  }

  factory TopicSignalDto.fromJson(Map<String, dynamic> json) => TopicSignalDto(
        id: json['id'] as String,
        signalType: json['signal_type'] as String,
        title: json['title'] as String,
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

class TopicHubBundle {
  const TopicHubBundle({
    required this.categorySlug,
    required this.categoryName,
    required this.categoryDescription,
    required this.hubTitle,
    required this.hubSummary,
    required this.blocks,
    required this.signals,
    required this.relatedEvents,
    required this.relatedReferences,
    required this.rooms,
  });

  final String categorySlug;
  final String categoryName;
  final String? categoryDescription;
  final String? hubTitle;
  final String? hubSummary;
  final List<KnowledgeBlockDto> blocks;
  final List<TopicSignalDto> signals;
  final List<EventCardDto> relatedEvents;
  final List<ReferenceDto> relatedReferences;
  final List<RoomSummaryDto> rooms;

  factory TopicHubBundle.fromJson(Map<String, dynamic> json) {
    final cat = (json['category'] as Map).cast<String, dynamic>();
    final hub = (json['hub'] as Map?)?.cast<String, dynamic>();
    return TopicHubBundle(
      categorySlug: cat['slug'] as String,
      categoryName: cat['name'] as String,
      categoryDescription: cat['description'] as String?,
      hubTitle: hub?['title'] as String?,
      hubSummary: hub?['summary'] as String?,
      blocks: (json['blocks'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(KnowledgeBlockDto.fromJson)
          .toList(growable: false),
      signals: (json['signals'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(TopicSignalDto.fromJson)
          .toList(growable: false),
      relatedEvents: (json['related_events'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(EventCardDto.fromJson)
          .toList(growable: false),
      relatedReferences: (json['related_references'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(ReferenceDto.fromJson)
          .toList(growable: false),
      rooms: (json['rooms'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(RoomSummaryDto.fromJson)
          .toList(growable: false),
    );
  }
}
