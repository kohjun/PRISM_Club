import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'curator_portfolio_dto.dart';

/// Client for `GET /v1/profiles/:userId/curator-portfolio` (P6.10).
class CuratorPortfolioRepository {
  CuratorPortfolioRepository(this._ref);
  final Ref _ref;

  Future<CuratorPortfolioDto> getForUser(String userId) async {
    try {
      final res = await _ref
          .read(dioProvider)
          .get<dynamic>('/profiles/$userId/curator-portfolio');
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          '큐레이터 포트폴리오를 불러오지 못했어요.',
          res.statusCode,
        );
      }
      return CuratorPortfolioDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final curatorPortfolioRepositoryProvider = Provider<CuratorPortfolioRepository>(
  (ref) => CuratorPortfolioRepository(ref),
);

final curatorPortfolioProvider =
    FutureProvider.family<CuratorPortfolioDto, String>((ref, userId) {
  return ref.read(curatorPortfolioRepositoryProvider).getForUser(userId);
});
