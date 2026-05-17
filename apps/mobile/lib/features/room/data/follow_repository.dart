import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';

class FollowStateDto {
  const FollowStateDto({required this.followed, required this.followerCount});
  final bool followed;
  final int followerCount;

  factory FollowStateDto.fromJson(Map<String, dynamic> json) => FollowStateDto(
        followed: json['followed'] as bool? ?? false,
        followerCount: json['follower_count'] as int? ?? 0,
      );
}

class FollowRepository {
  FollowRepository(this._ref);
  final Ref _ref;

  Future<FollowStateDto> getState(String roomSlug) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/rooms/$roomSlug/follow',
          );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to get follow state', res.statusCode);
      }
      return FollowStateDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<FollowStateDto> toggle(String roomSlug) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
            '/rooms/$roomSlug/follow',
          );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to toggle follow', res.statusCode);
      }
      return FollowStateDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final followRepositoryProvider =
    Provider<FollowRepository>((ref) => FollowRepository(ref));

class RoomFollowNotifier extends FamilyAsyncNotifier<FollowStateDto, String> {
  @override
  Future<FollowStateDto> build(String roomSlug) async {
    return ref.read(followRepositoryProvider).getState(roomSlug);
  }

  Future<void> toggle() async {
    final result = await ref.read(followRepositoryProvider).toggle(arg);
    state = AsyncData(result);
  }
}

final roomFollowProvider =
    AsyncNotifierProvider.family<RoomFollowNotifier, FollowStateDto, String>(
  RoomFollowNotifier.new,
);
