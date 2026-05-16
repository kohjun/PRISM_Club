import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'dev_user_dto.dart';

class AuthRepository {
  AuthRepository(this._ref);
  final Ref _ref;

  Future<List<DevUserDto>> listDevUsers() async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>('/dev/users');
      final body = res.data;
      if (res.statusCode != 200 || body is! List) {
        throw ApiError('UNEXPECTED', 'Unexpected /dev/users response', res.statusCode);
      }
      return body
          .whereType<Map<String, dynamic>>()
          .map(DevUserDto.fromJson)
          .toList(growable: false);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref));
