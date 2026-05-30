import '../../../core/json_helpers.dart';

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
      suggestedBody: asString(json, 'suggested_body'),
      suggestedAttachments: asObjectList(
        json,
        'suggested_attachments',
        RecapAttachmentDto.fromJson,
      ),
      suggestedRoomSlugs: asStringList(json, 'suggested_room_slugs'),
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
        title: asString(json, 'title'),
        startsAt: asString(json, 'starts_at'),
        venueName: asString(json, 'venue_name'),
        region: asString(json, 'region'),
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
        attachmentType: asString(json, 'attachment_type'),
        targetId: asString(json, 'target_id'),
      );
}
