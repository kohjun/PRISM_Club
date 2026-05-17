import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'user_profile_dto.dart';

class UserProfileRepository {
  UserProfileRepository(this._ref);
  final Ref _ref;

  Future<UserProfileBundleDto> getProfile(String userId) async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>(
            '/users/$userId/profile',
          );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to load profile', res.statusCode);
      }
      return UserProfileBundleDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<ProfileSubDto> updateMyProfile(UpdateProfileInput input) async {
    try {
      final res = await _ref.read(dioProvider).patch<dynamic>(
            '/me/profile',
            data: input.toJson(),
          );
      if (res.statusCode != 200) {
        throw ApiError('UNEXPECTED', 'Failed to update profile', res.statusCode);
      }
      return ProfileSubDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final userProfileRepositoryProvider =
    Provider<UserProfileRepository>((ref) => UserProfileRepository(ref));

final userProfileProvider =
    FutureProvider.family<UserProfileBundleDto, String>((ref, userId) {
  return ref.read(userProfileRepositoryProvider).getProfile(userId);
});
