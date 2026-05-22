import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'event_detail_dto.dart';

class ReviewRepository {
  ReviewRepository(this._ref);
  final Ref _ref;

  Future<EventReviewDto> createOrUpdate(
    String eventCardId, {
    required int rating,
    required String body,
  }) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
            '/event-cards/$eventCardId/reviews',
            data: {'rating': rating, 'body': body},
          );
      if (res.statusCode != 200) {
        throw ApiError.fromResponseBody(
          res.data,
          fallbackCode: 'REVIEW_FAILED',
          status: res.statusCode,
        );
      }
      return EventReviewDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final reviewRepositoryProvider =
    Provider<ReviewRepository>((ref) => ReviewRepository(ref));
