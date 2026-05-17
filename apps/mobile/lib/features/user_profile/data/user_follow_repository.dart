import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'user_profile_dto.dart';

class UserFollowRepository {
  UserFollowRepository(this._ref);
  final Ref _ref;

  Future<UserFollowStateDto> getState(String userId) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/users/$userId/follow-state',
          );
      if (res.statusCode != 200) {
        throw ApiError(
            'UNEXPECTED', 'Failed to get follow state', res.statusCode);
      }
      return UserFollowStateDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<UserFollowStateDto> toggle(String userId) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
            '/users/$userId/follow-toggle',
          );
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw ApiError('UNEXPECTED', 'Failed to toggle follow', res.statusCode);
      }
      return UserFollowStateDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final userFollowRepositoryProvider =
    Provider<UserFollowRepository>((ref) => UserFollowRepository(ref));

class UserFollowNotifier extends FamilyAsyncNotifier<UserFollowStateDto, String> {
  @override
  Future<UserFollowStateDto> build(String userId) async {
    return ref.read(userFollowRepositoryProvider).getState(userId);
  }

  Future<void> toggle() async {
    final result = await ref.read(userFollowRepositoryProvider).toggle(arg);
    state = AsyncData(result);
  }
}

final userFollowProvider = AsyncNotifierProvider.family<
    UserFollowNotifier, UserFollowStateDto, String>(UserFollowNotifier.new);
