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

  /// M12: refresh deterministic activity signals across all topic hubs.
  Future<({int hubsProcessed, int signalsWritten})> refreshSignals() async {
    try {
      final res = await _ref
          .read(dioProvider)
          .post<dynamic>('/admin/signals/refresh');
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw ApiError(
            'UNEXPECTED', 'Failed to refresh signals', res.statusCode);
      }
      final m = res.data as Map<String, dynamic>;
      return (
        hubsProcessed: m['hubs_processed'] as int? ?? 0,
        signalsWritten: m['signals_written'] as int? ?? 0,
      );
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
