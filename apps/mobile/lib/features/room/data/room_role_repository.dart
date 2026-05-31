import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'room_role_dto.dart';

/// Client for the P6.12 room-role endpoints. Grant/revoke are
/// owner-only server-side; the mobile only shows the management UI to
/// the owner, but the server is the real gate (403 otherwise).
class RoomRoleRepository {
  RoomRoleRepository(this._ref);
  final Ref _ref;

  Future<List<RoomRoleDto>> list(String slug) async {
    try {
      final res = await _ref
          .read(dioProvider)
          .get<dynamic>('/rooms/$slug/roles');
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', '모더 목록을 불러오지 못했어요.', res.statusCode);
      }
      final raw = (res.data as List?) ?? const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(RoomRoleDto.fromJson)
          .toList(growable: false);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> grant(String slug, String userId,
      {String role = 'MODERATOR'}) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/rooms/$slug/roles',
        data: {'user_id': userId, 'role': role},
      );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', '모더 추가에 실패했어요.', res.statusCode);
      }
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> revoke(String slug, String userId) async {
    try {
      final res = await _ref
          .read(dioProvider)
          .delete<dynamic>('/rooms/$slug/roles/$userId');
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', '모더 해제에 실패했어요.', res.statusCode);
      }
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final roomRoleRepositoryProvider =
    Provider<RoomRoleRepository>((ref) => RoomRoleRepository(ref));

final roomRolesProvider =
    FutureProvider.family<List<RoomRoleDto>, String>((ref, slug) {
  return ref.read(roomRoleRepositoryProvider).list(slug);
});
