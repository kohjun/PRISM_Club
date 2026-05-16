import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/current_user.dart';
import '../../../core/dio_provider.dart';
import 'me_dto.dart';

class MeRepository {
  MeRepository(this._ref);
  final Ref _ref;

  Future<MeDto> getMe() async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>('/me');
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to load /me', res.statusCode);
      }
      return MeDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final meRepositoryProvider = Provider<MeRepository>((ref) => MeRepository(ref));

/// Returns the signed-in user's `/v1/me` view (including roles).
/// Re-fetches when [currentUserProvider] changes so role-gated UI follows
/// account switching in the login picker.
final meProvider = FutureProvider<MeDto>((ref) {
  // Establish a dependency on the current user — switching users invalidates.
  ref.watch(currentUserProvider);
  return ref.read(meRepositoryProvider).getMe();
});
