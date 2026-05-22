import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';

class BoostResult {
  const BoostResult({
    required this.boostCount,
    required this.boostedByMe,
  });
  final int boostCount;
  final bool boostedByMe;

  factory BoostResult.fromJson(Map<String, dynamic> body) => BoostResult(
        boostCount: (body['boost_count'] as num?)?.toInt() ?? 0,
        boostedByMe: body['boosted_by_me'] as bool? ?? false,
      );
}

class BoostRepository {
  BoostRepository(this._ref);
  final Ref _ref;

  /// P6.6 toggle. Calling a second time removes the boost.
  Future<BoostResult> toggle(String postId) async {
    try {
      final res =
          await _ref.read(dioProvider).post<dynamic>('/posts/$postId/boost');
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Boost toggle failed', res.statusCode);
      }
      return BoostResult.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final boostRepositoryProvider =
    Provider<BoostRepository>((ref) => BoostRepository(ref));
