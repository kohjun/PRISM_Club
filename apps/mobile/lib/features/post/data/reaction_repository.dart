import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';

class ReactionResult {
  const ReactionResult({required this.liked, required this.likeCount});
  final bool liked;
  final int likeCount;
}

class ReactionRepository {
  ReactionRepository(this._ref);
  final Ref _ref;

  /// target_type ∈ {'POST', 'REPLY'}.
  Future<ReactionResult> toggleLike(String targetType, String targetId) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/reactions/toggle',
        data: {'target_type': targetType, 'target_id': targetId},
      );
      if (res.statusCode != 201 && res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Reaction toggle failed', res.statusCode);
      }
      final body = res.data as Map<String, dynamic>;
      return ReactionResult(
        liked: body['liked'] as bool,
        likeCount: body['like_count'] as int,
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final reactionRepositoryProvider =
    Provider<ReactionRepository>((ref) => ReactionRepository(ref));
