import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'reputation_dto.dart';

class ReputationRepository {
  ReputationRepository(this._ref);
  final Ref _ref;

  Future<ReputationDto> getForUser(String userId) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/users/$userId/reputation',
          );
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Failed to load reputation',
          res.statusCode,
        );
      }
      return ReputationDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final reputationRepositoryProvider =
    Provider<ReputationRepository>((ref) => ReputationRepository(ref));

final userReputationProvider = FutureProvider.family<ReputationDto, String>(
  (ref, userId) =>
      ref.read(reputationRepositoryProvider).getForUser(userId),
);
