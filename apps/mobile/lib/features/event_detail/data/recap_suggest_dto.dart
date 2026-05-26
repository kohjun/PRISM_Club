/// Response from `POST /v1/event-cards/:id/recap/suggest`.
///
/// The server returns a deterministic markdown-shaped body the organizer
/// can drop straight into the composer. Nothing is persisted server-side
/// — the recap becomes a real post only when the user hits publish in
/// the composer (normal `POST /v1/rooms/:slug/posts` flow).
class RecapSuggestionDto {
  const RecapSuggestionDto({
    required this.event,
    required this.suggestedBody,
    required this.suggestedAttachments,
    required this.suggestedRoomSlugs,
  });

  final RecapEventDto event;
  final String suggestedBody;
  final List<RecapAttachmentDto> suggestedAttachments;
  final List<String> suggestedRoomSlugs;

  factory RecapSuggestionDto.fromJson(Map<String, dynamic> json) {
    return RecapSuggestionDto(
      event: RecapEventDto.fromJson(json['event'] as Map<String, dynamic>),
      suggestedBody: json['suggested_body'] as String? ?? '',
      suggestedAttachments: ((json['suggested_attachments'] as List?) ??
              const [])
          .whereType<Map<String, dynamic>>()
          .map(RecapAttachmentDto.fromJson)
          .toList(growable: false),
      suggestedRoomSlugs:
          ((json['suggested_room_slugs'] as List?) ?? const [])
              .whereType<String>()
              .toList(growable: false),
    );
  }
}

class RecapEventDto {
  const RecapEventDto({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.venueName,
    required this.region,
  });

  final String id;
  final String title;
  final String startsAt;
  final String venueName;
  final String region;

  factory RecapEventDto.fromJson(Map<String, dynamic> json) => RecapEventDto(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        startsAt: json['starts_at'] as String? ?? '',
        venueName: json['venue_name'] as String? ?? '',
        region: json['region'] as String? ?? '',
      );
}

class RecapAttachmentDto {
  const RecapAttachmentDto({
    required this.attachmentType,
    required this.targetId,
  });

  final String attachmentType;
  final String targetId;

  factory RecapAttachmentDto.fromJson(Map<String, dynamic> json) =>
      RecapAttachmentDto(
        attachmentType: json['attachment_type'] as String? ?? '',
        targetId: json['target_id'] as String? ?? '',
      );
}
