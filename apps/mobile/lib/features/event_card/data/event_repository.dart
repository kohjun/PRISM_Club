import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'event_card_dto.dart';
import 'external_event_dto.dart';

class EventRepository {
  EventRepository(this._ref);
  final Ref _ref;

  Future<List<ExternalEventDto>> search(String q, {String? status}) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
        '/events/search',
        queryParameters: {
          if (q.isNotEmpty) 'q': q,
          'status': ?status,
        },
      );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Event search failed', res.statusCode);
      }
      final items = (res.data as Map)['items'] as List<dynamic>;
      return items
          .whereType<Map<String, dynamic>>()
          .map(ExternalEventDto.fromJson)
          .toList(growable: false);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<EventCardDto> upsert(String externalEventId) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/event-cards',
        data: {'external_event_id': externalEventId},
      );
      if (res.statusCode != 201 && res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Event card upsert failed', res.statusCode);
      }
      return EventCardDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final eventRepositoryProvider =
    Provider<EventRepository>((ref) => EventRepository(ref));
