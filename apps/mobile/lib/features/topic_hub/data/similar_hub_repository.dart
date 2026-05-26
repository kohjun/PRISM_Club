import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'similar_hub_dto.dart';

/// Client for `GET /v1/topic-hubs/:slug/similar`. Public-readable so we
/// don't need a session header; the AccessControl gate runs server-side
/// per response row. Empty array → mobile section hides itself.
class SimilarHubRepository {
  SimilarHubRepository(this._ref);
  final Ref _ref;

  Future<List<SimilarHubDto>> listForHub(String slug, {int limit = 5}) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/topic-hubs/$slug/similar',
            queryParameters: {'limit': limit},
          );
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'similar topic-hubs 호출이 실패했어요.',
          res.statusCode,
        );
      }
      final raw = (res.data as List?) ?? const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(SimilarHubDto.fromJson)
          .toList(growable: false);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final similarHubRepositoryProvider =
    Provider<SimilarHubRepository>((ref) => SimilarHubRepository(ref));

/// Cached list keyed on the category/hub slug. The Topic Hub screen
/// watches this from a single widget so the strip self-hides cleanly
/// on empty responses without any extra state plumbing.
final similarHubsProvider =
    FutureProvider.family<List<SimilarHubDto>, String>((ref, slug) {
  return ref.read(similarHubRepositoryProvider).listForHub(slug);
});
