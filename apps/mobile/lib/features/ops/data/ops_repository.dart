import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'ops_dto.dart';

class OpsRepository {
  OpsRepository(this._ref);
  final Ref _ref;

  Future<OpsSummaryDto> getSummary() async {
    try {
      final res =
          await _ref.read(dioProvider).get<dynamic>('/admin/ops/summary');
      if (res.statusCode != 200) {
        throw ApiError(
            'UNEXPECTED', 'Failed to load ops summary', res.statusCode);
      }
      return OpsSummaryDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final opsRepositoryProvider =
    Provider<OpsRepository>((ref) => OpsRepository(ref));

final opsSummaryProvider = FutureProvider<OpsSummaryDto>((ref) {
  return ref.read(opsRepositoryProvider).getSummary();
});
