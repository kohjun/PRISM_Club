import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'recap_suggest_dto.dart';

/// Client for `POST /v1/event-cards/:id/recap/suggest`.
///
/// Idempotent server-side, but we treat each call as a fresh request so
/// the user gets up-to-date numbers if reviews / live posts landed
/// between opening event detail and tapping the CTA.
class RecapSuggestRepository {
  RecapSuggestRepository(this._ref);
  final Ref _ref;

  Future<RecapSuggestionDto> suggest(String eventCardId) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
            '/event-cards/$eventCardId/recap/suggest',
          );
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'recap suggest 호출이 실패했어요.',
          res.statusCode,
        );
      }
      return RecapSuggestionDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final recapSuggestRepositoryProvider =
    Provider<RecapSuggestRepository>((ref) => RecapSuggestRepository(ref));
