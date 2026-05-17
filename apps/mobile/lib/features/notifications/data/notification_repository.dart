import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'notification_dto.dart';

class NotificationRepository {
  NotificationRepository(this._ref);
  final Ref _ref;

  Future<NotificationListDto> list({
    String? cursor,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/me/notifications',
            queryParameters: {
              'limit': limit,
              if (cursor != null) 'cursor': cursor,
              if (unreadOnly) 'unread_only': 'true',
            },
          );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to load notifications', res.statusCode);
      }
      return NotificationListDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> markRead(String id) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
            '/me/notifications/$id/read',
          );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to mark notification read', res.statusCode);
      }
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<int> markAllRead() async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
            '/me/notifications/read-all',
          );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to mark all read', res.statusCode);
      }
      final body = res.data as Map<String, dynamic>;
      return body['updated_count'] as int? ?? 0;
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/me/notifications/unread-count',
          );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to get unread count', res.statusCode);
      }
      final body = res.data as Map<String, dynamic>;
      return body['count'] as int? ?? 0;
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository(ref));

final notificationsProvider = FutureProvider<NotificationListDto>((ref) {
  return ref.read(notificationRepositoryProvider).list();
});

final unreadCountProvider = FutureProvider<int>((ref) {
  return ref.read(notificationRepositoryProvider).getUnreadCount();
});
