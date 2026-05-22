import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'event_digest_dto.dart';

class EventDigestRepository {
  EventDigestRepository(this._ref);
  final Ref _ref;

  Future<EventDigestDto?> getForEvent(String eventCardId) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/event-cards/$eventCardId/digest',
          );
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Failed to load recap',
          res.statusCode,
        );
      }
      final body = res.data;
      if (body == null || body == '' || body is! Map) return null;
      return EventDigestDto.fromJson(body.cast<String, dynamic>());
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final eventDigestRepositoryProvider =
    Provider<EventDigestRepository>((ref) => EventDigestRepository(ref));

final eventRecapProvider = FutureProvider.family<EventDigestDto?, String>(
  (ref, eventCardId) =>
      ref.read(eventDigestRepositoryProvider).getForEvent(eventCardId),
);
