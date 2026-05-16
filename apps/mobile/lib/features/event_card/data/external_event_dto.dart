/// Returned by `GET /v1/events/search` — the unresolved external event,
/// not yet materialized as an EventCard. The mobile app calls
/// `POST /v1/event-cards` with `external_event_id` to convert it.
class ExternalEventDto {
  const ExternalEventDto({
    required this.externalEventId,
    required this.title,
    required this.venueName,
    required this.region,
    required this.startsAt,
    required this.eventStatus,
    required this.thumbnailUrl,
  });

  final String externalEventId;
  final String title;
  final String venueName;
  final String region;
  final DateTime startsAt;
  final String eventStatus;
  final String? thumbnailUrl;

  bool get isCompleted => eventStatus == 'COMPLETED';

  factory ExternalEventDto.fromJson(Map<String, dynamic> json) => ExternalEventDto(
        externalEventId: json['external_event_id'] as String,
        title: json['title'] as String,
        venueName: json['venue_name'] as String,
        region: json['region'] as String,
        startsAt: DateTime.parse(json['starts_at'] as String),
        eventStatus: json['event_status'] as String,
        thumbnailUrl: json['thumbnail_url'] as String?,
      );
}
