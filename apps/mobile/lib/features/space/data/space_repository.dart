import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'space_dto.dart';

class SpaceRepository {
  SpaceRepository(this._ref);
  final Ref _ref;

  Future<List<SpaceDto>> listSpaces() async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>('/spaces');
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to load spaces', res.statusCode);
      }
      final body = res.data as Map<String, dynamic>;
      final items = body['items'] as List<dynamic>;
      return items
          .whereType<Map<String, dynamic>>()
          .map(SpaceDto.fromJson)
          .toList(growable: false);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final spaceRepositoryProvider =
    Provider<SpaceRepository>((ref) => SpaceRepository(ref));

final spaceListProvider = FutureProvider<List<SpaceDto>>(
  (ref) => ref.read(spaceRepositoryProvider).listSpaces(),
);
