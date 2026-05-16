import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'search_dto.dart';

class SearchRepository {
  SearchRepository(this._ref);
  final Ref _ref;

  Future<SearchResponseDto> search({
    required String query,
    Set<String>? types,
    int? limit,
  }) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
        '/search',
        queryParameters: {
          'q': query,
          'types': ?(types == null || types.isEmpty ? null : types.join(',')),
          'limit': ?limit,
        },
      );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Search failed', res.statusCode);
      }
      return SearchResponseDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<List<String>> suggestions({String? categorySlug}) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
        '/search/suggestions',
        queryParameters: {'categorySlug': ?categorySlug},
      );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Suggestions failed', res.statusCode);
      }
      final items = (res.data as Map)['items'] as List<dynamic>;
      return items.whereType<String>().toList(growable: false);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final searchRepositoryProvider =
    Provider<SearchRepository>((ref) => SearchRepository(ref));

/// Cached per (categorySlug ?? '') so the chip rows on different Topic Hubs
/// don't re-fetch. M3 returns the same list for everyone, but the call shape
/// is ready when we wire dynamic suggestions later.
final searchSuggestionsProvider =
    FutureProvider.family<List<String>, String?>((ref, categorySlug) {
  return ref.read(searchRepositoryProvider).suggestions(categorySlug: categorySlug);
});
