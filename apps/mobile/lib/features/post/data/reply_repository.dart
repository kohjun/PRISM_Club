import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'reply_dto.dart';

class ReplyRepository {
  ReplyRepository(this._ref);
  final Ref _ref;

  Future<List<ReplyDto>> listByPost(String postId) async {
    try {
      final res =
          await _ref.read(dioProvider).get<dynamic>('/posts/$postId/replies');
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Replies load failed', res.statusCode);
      }
      final items = (res.data as Map)['items'] as List<dynamic>;
      return items
          .whereType<Map<String, dynamic>>()
          .map(ReplyDto.fromJson)
          .toList(growable: false);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<ReplyDto> create(
    String postId, {
    required String body,
    String? parentReplyId,
  }) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/posts/$postId/replies',
        data: {
          'body': body,
          'parent_reply_id': ?parentReplyId,
        },
      );
      if (res.statusCode != 201) {
        throw ApiError('UNEXPECTED', 'Reply create failed', res.statusCode);
      }
      return ReplyDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final replyRepositoryProvider =
    Provider<ReplyRepository>((ref) => ReplyRepository(ref));

final repliesProvider =
    FutureProvider.family<List<ReplyDto>, String>((ref, postId) {
  return ref.read(replyRepositoryProvider).listByPost(postId);
});
