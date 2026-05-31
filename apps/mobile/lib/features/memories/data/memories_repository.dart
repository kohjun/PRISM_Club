import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'memories_dto.dart';

/// Client for `GET /v1/me/memories`. Auth-required (me-scoped). An
/// empty `items` list means today has no anniversary activity — the
/// home card self-hides in that case.
class MemoriesRepository {
  MemoriesRepository(this._ref);
  final Ref _ref;

  Future<MemoriesDto> getMemories({String? date}) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/me/memories',
            queryParameters: {'date': ?date},
          );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', '오늘의 기록을 불러오지 못했어요.', res.statusCode);
      }
      return MemoriesDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final memoriesRepositoryProvider =
    Provider<MemoriesRepository>((ref) => MemoriesRepository(ref));

/// Today's memories. Watched by the home card (self-hides on empty /
/// error / loading) and the detail screen.
final todayMemoriesProvider = FutureProvider<MemoriesDto>((ref) {
  return ref.read(memoriesRepositoryProvider).getMemories();
});
