import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'category_dto.dart';

class CategoryRepository {
  CategoryRepository(this._ref);
  final Ref _ref;

  Future<List<CategoryDto>> listBySpaceSlug(String spaceSlug) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/categories',
            queryParameters: {'spaceSlug': spaceSlug},
          );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to load categories', res.statusCode);
      }
      final body = res.data as Map<String, dynamic>;
      final items = body['items'] as List<dynamic>;
      return items
          .whereType<Map<String, dynamic>>()
          .map(CategoryDto.fromJson)
          .toList(growable: false);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final categoryRepositoryProvider =
    Provider<CategoryRepository>((ref) => CategoryRepository(ref));

final categoryListProvider =
    FutureProvider.family<List<CategoryDto>, String>((ref, spaceSlug) {
  return ref.read(categoryRepositoryProvider).listBySpaceSlug(spaceSlug);
});
