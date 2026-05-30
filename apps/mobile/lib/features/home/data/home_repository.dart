import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'home_dto.dart';

class HomeRepository {
  HomeRepository(this._ref);
  final Ref _ref;

  Future<HomeBundleDto> getBundle() async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>('/home');
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to load home bundle', res.statusCode);
      }
      return HomeBundleDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<HomeFeedPageDto> getFeed({String? cursor, int limit = 20}) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/home/feed',
            queryParameters: {
              'limit': limit,
              'cursor': ?cursor,
            },
          );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to load home feed', res.statusCode);
      }
      return HomeFeedPageDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final homeRepositoryProvider =
    Provider<HomeRepository>((ref) => HomeRepository(ref));

final homeBundleProvider = FutureProvider<HomeBundleDto>((ref) {
  return ref.read(homeRepositoryProvider).getBundle();
});
