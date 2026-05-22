import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';

class EventLiveAuthorDto {
  const EventLiveAuthorDto({
    required this.id,
    required this.nickname,
    this.avatarUrl,
  });
  final String id;
  final String nickname;
  final String? avatarUrl;

  factory EventLiveAuthorDto.fromJson(Map<String, dynamic> json) =>
      EventLiveAuthorDto(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        avatarUrl: json['avatar_url'] as String?,
      );
}

class EventLiveImageDto {
  const EventLiveImageDto({required this.id, this.cdnUrl, this.width, this.height});
  final String id;
  final String? cdnUrl;
  final int? width;
  final int? height;

  factory EventLiveImageDto.fromJson(Map<String, dynamic> json) =>
      EventLiveImageDto(
        id: json['id'] as String,
        cdnUrl: json['cdn_url'] as String?,
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
      );
}

class EventLivePostDto {
  const EventLivePostDto({
    required this.id,
    required this.body,
    required this.author,
    required this.createdAt,
    this.image,
  });
  final String id;
  final String body;
  final EventLiveAuthorDto author;
  final DateTime createdAt;
  final EventLiveImageDto? image;

  factory EventLivePostDto.fromJson(Map<String, dynamic> json) =>
      EventLivePostDto(
        id: json['id'] as String,
        body: json['body'] as String,
        author: EventLiveAuthorDto.fromJson(
          (json['author'] as Map).cast<String, dynamic>(),
        ),
        createdAt: DateTime.parse(json['created_at'] as String),
        image: json['image'] is Map
            ? EventLiveImageDto.fromJson(
                (json['image'] as Map).cast<String, dynamic>(),
              )
            : null,
      );
}

class EventLiveRepository {
  EventLiveRepository(this._ref);
  final Ref _ref;

  Future<List<EventLivePostDto>> list(String eventCardId) async {
    try {
      final res = await _ref
          .read(dioProvider)
          .get<dynamic>('/event-cards/$eventCardId/live');
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Failed to load live strip',
          res.statusCode,
        );
      }
      final body = res.data as Map<String, dynamic>;
      return (body['items'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(EventLivePostDto.fromJson)
          .toList(growable: false);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<EventLivePostDto> create(
    String eventCardId,
    String body, {
    String? imageMediaId,
  }) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/event-cards/$eventCardId/live',
        data: {
          'body': body,
          if (imageMediaId != null) 'image_media_id': imageMediaId,
        },
      );
      if (res.statusCode != 201 && res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Failed to post live entry',
          res.statusCode,
        );
      }
      return EventLivePostDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final eventLiveRepositoryProvider =
    Provider<EventLiveRepository>((ref) => EventLiveRepository(ref));

final eventLiveListProvider = FutureProvider.family<List<EventLivePostDto>, String>(
  (ref, cardId) => ref.read(eventLiveRepositoryProvider).list(cardId),
);
