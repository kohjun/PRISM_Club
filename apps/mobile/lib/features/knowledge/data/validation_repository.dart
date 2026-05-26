import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'validation_dto.dart';

/// Client for `GET /v1/knowledge-blocks/:blockId/validation`.
class ValidationRepository {
  ValidationRepository(this._ref);
  final Ref _ref;

  Future<ValidationDto> getForBlock(String blockId) async {
    try {
      final res = await _ref
          .read(dioProvider)
          .get<dynamic>('/knowledge-blocks/$blockId/validation');
      if (res.statusCode != 200) {
        throw ApiError(
          'UNEXPECTED',
          '검증 강도 호출이 실패했어요.',
          res.statusCode,
        );
      }
      return ValidationDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final validationRepositoryProvider =
    Provider<ValidationRepository>((ref) => ValidationRepository(ref));

/// Per-block validation, cached by Riverpod's family so multiple
/// badges on the same Topic Hub screen don't duplicate the call. The
/// badge widget watches this as a `.when` so the chip self-hides
/// during loading / on error.
final blockValidationProvider =
    FutureProvider.family<ValidationDto, String>((ref, blockId) {
  return ref.read(validationRepositoryProvider).getForBlock(blockId);
});
