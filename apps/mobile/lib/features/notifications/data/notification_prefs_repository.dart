import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'notification_dto.dart';

/// `GET / PATCH /v1/me/notification-preferences` (P1.2).
///
/// The server lazy-creates the preference row on first read, so `get()`
/// always succeeds for an authenticated user.
class NotificationPrefsRepository {
  NotificationPrefsRepository(this._ref);
  final Ref _ref;

  Future<NotificationPreferencesDto> get() async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/me/notification-preferences',
          );
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Failed to load notification preferences',
          res.statusCode,
        );
      }
      return NotificationPreferencesDto.fromJson(
        res.data as Map<String, dynamic>,
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// PATCH a single field. The server merges and returns the full row.
  Future<NotificationPreferencesDto> patch(
    Map<String, bool> partial,
  ) async {
    try {
      final res = await _ref.read(dioProvider).patch<dynamic>(
            '/me/notification-preferences',
            data: partial,
          );
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Failed to update notification preferences',
          res.statusCode,
        );
      }
      return NotificationPreferencesDto.fromJson(
        res.data as Map<String, dynamic>,
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final notificationPrefsRepositoryProvider =
    Provider<NotificationPrefsRepository>(
  (ref) => NotificationPrefsRepository(ref),
);

final notificationPrefsProvider =
    FutureProvider<NotificationPreferencesDto>((ref) {
  return ref.read(notificationPrefsRepositoryProvider).get();
});
