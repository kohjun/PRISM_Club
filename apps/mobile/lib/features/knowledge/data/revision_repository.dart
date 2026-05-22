import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'revision_dto.dart';

class RevisionRepository {
  RevisionRepository(this._ref);
  final Ref _ref;

  Future<RevisionListDto> listForBlock(
    String blockId, {
    String? cursor,
    int limit = 50,
  }) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/knowledge-blocks/$blockId/revisions',
            queryParameters: {
              'limit': limit,
              if (cursor != null) 'cursor': cursor,
            },
          );
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          'Failed to load revisions',
          res.statusCode,
        );
      }
      return RevisionListDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final revisionRepositoryProvider =
    Provider<RevisionRepository>((ref) => RevisionRepository(ref));

final blockRevisionsProvider = FutureProvider.family<RevisionListDto, String>(
  (ref, blockId) =>
      ref.read(revisionRepositoryProvider).listForBlock(blockId),
);
