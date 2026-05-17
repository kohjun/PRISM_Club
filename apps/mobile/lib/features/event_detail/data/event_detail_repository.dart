import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import '../../event_card/data/event_card_dto.dart';
import 'event_detail_dto.dart';

class EventDetailRepository {
  EventDetailRepository(this._ref);
  final Ref _ref;

  Future<EventDetailBundleDto> getBundle(String cardId) async {
    try {
      final res = await _ref
          .read(dioProvider)
          .get<dynamic>('/event-cards/$cardId');
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Event detail load failed', res.statusCode);
      }
      return EventDetailBundleDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// Thin lookup used by the composer pre-attach flow.
  /// Re-reads only the `event_card` portion of the detail bundle.
  Future<EventCardDto> getEventCardById(String cardId) async {
    final bundle = await getBundle(cardId);
    return bundle.eventCard;
  }
}

final eventDetailRepositoryProvider =
    Provider<EventDetailRepository>((ref) => EventDetailRepository(ref));

final eventDetailProvider =
    FutureProvider.family<EventDetailBundleDto, String>((ref, cardId) {
  return ref.read(eventDetailRepositoryProvider).getBundle(cardId);
});
