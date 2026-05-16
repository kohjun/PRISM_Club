class EventCardDto {
  const EventCardDto({
    required this.id,
    required this.externalEventId,
    required this.title,
    required this.venueName,
    required this.region,
    required this.startsAt,
    required this.eventStatus,
    required this.thumbnailUrl,
  });

  final String id;
  final String externalEventId;
  final String title;
  final String venueName;
  final String region;
  final DateTime startsAt;
  final String eventStatus; // UPCOMING | COMPLETED
  final String? thumbnailUrl;

  bool get isCompleted => eventStatus == 'COMPLETED';

  factory EventCardDto.fromJson(Map<String, dynamic> json) => EventCardDto(
        id: json['id'] as String,
        externalEventId: json['external_event_id'] as String,
        title: json['title'] as String,
        venueName: json['venue_name'] as String,
        region: json['region'] as String,
        startsAt: DateTime.parse(json['starts_at'] as String),
        eventStatus: json['event_status'] as String,
        thumbnailUrl: json['thumbnail_url'] as String?,
      );
}
