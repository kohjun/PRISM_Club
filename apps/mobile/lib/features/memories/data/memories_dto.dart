import '../../../core/json_helpers.dart';

/// Response from `GET /v1/me/memories`. P6.11 "오늘의 기록" — the
/// viewer's own activity 1 and 2 years ago on this calendar day.
class MemoriesDto {
  const MemoriesDto({required this.date, required this.items});

  final String date;
  final List<MemoryItemDto> items;

  bool get isEmpty => items.isEmpty;

  factory MemoriesDto.fromJson(Map<String, dynamic> json) => MemoriesDto(
        date: asString(json, 'date'),
        items: asObjectList(json, 'items', MemoryItemDto.fromJson),
      );
}

class MemoryItemDto {
  const MemoryItemDto({
    required this.kind,
    required this.yearsAgo,
    required this.actedAt,
    required this.title,
    required this.subtitle,
    required this.deepLink,
  });

  /// ROOM_FOLLOW | CONTRIBUTION_APPROVED | EVENT_RSVP
  final String kind;
  final int yearsAgo;
  final String actedAt;
  final String title;
  final String subtitle;
  final String deepLink;

  factory MemoryItemDto.fromJson(Map<String, dynamic> json) => MemoryItemDto(
        kind: asString(json, 'kind'),
        yearsAgo: asInt(json, 'years_ago'),
        actedAt: asString(json, 'acted_at'),
        title: asString(json, 'title'),
        subtitle: asString(json, 'subtitle'),
        deepLink: asString(json, 'deep_link'),
      );
}
