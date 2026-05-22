import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'post_dto.dart';

class PollRepository {
  PollRepository(this._ref);
  final Ref _ref;

  Future<PollDto> vote(String pollId, String optionId) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/polls/$pollId/votes',
        data: {'option_id': optionId},
      );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Vote failed', res.statusCode);
      }
      return PollDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<PollDto> clearVotes(String pollId) async {
    try {
      final res = await _ref
          .read(dioProvider)
          .delete<dynamic>('/polls/$pollId/votes');
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Clear votes failed',
          res.statusCode,
        );
      }
      return PollDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final pollRepositoryProvider =
    Provider<PollRepository>((ref) => PollRepository(ref));
