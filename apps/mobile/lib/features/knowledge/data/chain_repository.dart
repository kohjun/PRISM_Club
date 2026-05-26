import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'chain_dto.dart';

/// Client for `GET /v1/knowledge-blocks/:blockId/chain`.
class ChainRepository {
  ChainRepository(this._ref);
  final Ref _ref;

  Future<ChainDto> getForBlock(String blockId) async {
    try {
      final res = await _ref
          .read(dioProvider)
          .get<dynamic>('/knowledge-blocks/$blockId/chain');
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          '기여자 체인 호출이 실패했어요.',
          res.statusCode,
        );
      }
      return ChainDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final chainRepositoryProvider =
    Provider<ChainRepository>((ref) => ChainRepository(ref));

final blockChainProvider =
    FutureProvider.family<ChainDto, String>((ref, blockId) {
  return ref.read(chainRepositoryProvider).getForBlock(blockId);
});
