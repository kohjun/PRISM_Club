import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';

/// P6.2 entry shown in `/me/blocks` and `/me/mutes` management screens.
class BlockMuteEntryDto {
  const BlockMuteEntryDto({
    required this.userId,
    required this.createdAt,
    this.nickname,
    this.avatarUrl,
  });
  final String userId;
  final String? nickname;
  final String? avatarUrl;
  final DateTime createdAt;

  factory BlockMuteEntryDto.fromJson(Map<String, dynamic> json) =>
      BlockMuteEntryDto(
        userId: json['user_id'] as String,
        nickname: json['nickname'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class BlockMuteRepository {
  BlockMuteRepository(this._ref);
  final Ref _ref;

  Future<List<BlockMuteEntryDto>> listBlocks() async {
    return _list('/me/blocks');
  }

  Future<List<BlockMuteEntryDto>> listMutes() async {
    return _list('/me/mutes');
  }

  Future<void> block(String userId) async {
    await _post('/me/blocks/$userId');
  }

  Future<void> unblock(String userId) async {
    await _delete('/me/blocks/$userId');
  }

  Future<void> mute(String userId) async {
    await _post('/me/mutes/$userId');
  }

  Future<void> unmute(String userId) async {
    await _delete('/me/mutes/$userId');
  }

  Future<List<BlockMuteEntryDto>> _list(String path) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(path);
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed: $path', res.statusCode);
      }
      final body = res.data as Map<String, dynamic>;
      return (body['items'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(BlockMuteEntryDto.fromJson)
          .toList(growable: false);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> _post(String path) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(path);
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed: $path', res.statusCode);
      }
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> _delete(String path) async {
    try {
      final res = await _ref.read(dioProvider).delete<dynamic>(path);
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed: $path', res.statusCode);
      }
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final blockMuteRepositoryProvider =
    Provider<BlockMuteRepository>((ref) => BlockMuteRepository(ref));

final blockListProvider = FutureProvider<List<BlockMuteEntryDto>>(
  (ref) => ref.read(blockMuteRepositoryProvider).listBlocks(),
);

final muteListProvider = FutureProvider<List<BlockMuteEntryDto>>(
  (ref) => ref.read(blockMuteRepositoryProvider).listMutes(),
);
