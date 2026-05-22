import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';

/// P6.4 reaction palette. MUST stay in lockstep with
/// `apps/api/src/modules/posts/reaction.service.ts:REACTION_TYPES`.
const List<String> kReactionTypes = [
  'HEART',
  'THUMBS_UP',
  'FIRE',
  'THINK',
  'IDEA',
  'LAUGH',
];

/// Korean labels for the palette tooltips + summary chip.
const Map<String, String> kReactionLabel = {
  'HEART': '좋아요',
  'THUMBS_UP': '도움돼요',
  'FIRE': '흥미로워요',
  'THINK': '생각나게 해요',
  'IDEA': '인사이트',
  'LAUGH': '재밌어요',
};

/// Unicode emoji rendering for each type.
const Map<String, String> kReactionEmoji = {
  'HEART': '❤️',
  'THUMBS_UP': '👍',
  'FIRE': '🔥',
  'THINK': '🤔',
  'IDEA': '💡',
  'LAUGH': '😂',
};

class ReactionResult {
  const ReactionResult({
    required this.liked,
    required this.likeCount,
    required this.myReaction,
    required this.reactionCounts,
  });
  final bool liked;
  final int likeCount;
  final String? myReaction;
  final Map<String, int> reactionCounts;

  factory ReactionResult.fromJson(Map<String, dynamic> body) {
    final my = body['my_reaction'] as String?;
    final counts = (body['reaction_counts'] as Map?)?.cast<String, dynamic>() ?? {};
    return ReactionResult(
      liked: my != null,
      likeCount: (body['like_count'] as num?)?.toInt() ?? 0,
      myReaction: my,
      reactionCounts: {
        for (final t in kReactionTypes) t: (counts[t] as num?)?.toInt() ?? 0,
      },
    );
  }
}

class ReactionRepository {
  ReactionRepository(this._ref);
  final Ref _ref;

  /// P6.4 toggle. `reactionType` defaults to `HEART` so callers that
  /// haven't migrated to the palette keep working.
  ///
  /// target_type ∈ {'POST', 'REPLY'}.
  Future<ReactionResult> toggle(
    String targetType,
    String targetId, {
    String reactionType = 'HEART',
  }) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/reactions/toggle',
        data: {
          'target_type': targetType,
          'target_id': targetId,
          'reaction_type': reactionType,
        },
      );
      if (res.statusCode != 201 && res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Reaction toggle failed', res.statusCode);
      }
      return ReactionResult.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// Back-compat alias — old call sites that only know about a binary
  /// "like" land on HEART.
  Future<ReactionResult> toggleLike(String targetType, String targetId) =>
      toggle(targetType, targetId);
}

final reactionRepositoryProvider =
    Provider<ReactionRepository>((ref) => ReactionRepository(ref));
