import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'event_detail_dto.dart';

class RsvpRepository {
  RsvpRepository(this._ref);
  final Ref _ref;

  /// Set or update RSVP status.
  Future<void> setRsvp(String eventCardId, String status) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
            '/event-cards/$eventCardId/rsvp',
            data: {'status': status},
          );
      if (res.statusCode != 200) {
        throw ApiError.fromResponseBody(
          res.data,
          fallbackCode: 'RSVP_FAILED',
          status: res.statusCode,
        );
      }
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> remove(String eventCardId) async {
    try {
      await _ref.read(dioProvider).delete<dynamic>(
            '/event-cards/$eventCardId/rsvp',
          );
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<RsvpStateDto> getState(String eventCardId) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/event-cards/$eventCardId/rsvp-state',
          );
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Failed to load RSVP state',
          res.statusCode,
        );
      }
      return RsvpStateDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final rsvpRepositoryProvider =
    Provider<RsvpRepository>((ref) => RsvpRepository(ref));
