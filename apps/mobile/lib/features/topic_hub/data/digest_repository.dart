import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'digest_dto.dart';

/// `GET /v1/categories/:slug/digest`. Returns null when the API has no
/// digest for the requested period — the weekly_digest_section hides
/// itself in that case, so a fresh hub doesn't show an empty card.
class DigestRepository {
  DigestRepository(this._ref);
  final Ref _ref;

  Future<DigestDto?> getForCategory(
    String slug, {
    String period = 'current',
  }) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/categories/$slug/digest',
            queryParameters: {'period': period},
          );
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Failed to load digest',
          res.statusCode,
        );
      }
      final body = res.data;
      if (body == null || body == '' || body is! Map) return null;
      return DigestDto.fromJson(body.cast<String, dynamic>());
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final digestRepositoryProvider =
    Provider<DigestRepository>((ref) => DigestRepository(ref));

final categoryDigestProvider =
    FutureProvider.family<DigestDto?, String>(
  (ref, slug) => ref.read(digestRepositoryProvider).getForCategory(slug),
);
