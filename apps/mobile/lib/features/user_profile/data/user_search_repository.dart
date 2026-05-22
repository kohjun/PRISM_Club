import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';

class UserSearchHitDto {
  const UserSearchHitDto({
    required this.id,
    required this.nickname,
    this.avatarUrl,
  });
  final String id;
  final String nickname;
  final String? avatarUrl;

  factory UserSearchHitDto.fromJson(Map<String, dynamic> json) =>
      UserSearchHitDto(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        avatarUrl: json['avatar_url'] as String?,
      );
}

class UserSearchRepository {
  UserSearchRepository(this._ref);
  final Ref _ref;

  /// P6.1: mention autocomplete. Returns up to 8 nickname matches.
  Future<List<UserSearchHitDto>> searchByNickname(String prefix) async {
    final trimmed = prefix.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
        '/users/search',
        queryParameters: {'q': trimmed},
      );
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Failed to search nicknames',
          res.statusCode,
        );
      }
      final data = res.data as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(UserSearchHitDto.fromJson)
          .toList(growable: false);
      return items;
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final userSearchRepositoryProvider =
    Provider<UserSearchRepository>((ref) => UserSearchRepository(ref));
