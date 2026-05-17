import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'dev_user_dto.dart';

class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.userId,
    required this.nickname,
    required this.roles,
  });
  final String accessToken;
  final String userId;
  final String nickname;
  final List<String> roles;
}

class AuthRepository {
  AuthRepository(this._ref);
  final Ref _ref;

  Future<List<DevUserDto>> listDevUsers() async {
    try {
      final res = await _ref.read(dioProvider).get<dynamic>('/dev/users');
      final body = res.data;
      if (res.statusCode != 200 || body is! List) {
        throw ApiError(
            'UNEXPECTED', 'Unexpected /dev/users response', res.statusCode);
      }
      return body
          .whereType<Map<String, dynamic>>()
          .map(DevUserDto.fromJson)
          .toList(growable: false);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// M13: passwordless dev login. Sends a user id; gets a JWT back.
  Future<LoginResult> login(String userId) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/auth/login',
        data: {'user_id': userId},
      );
      if (res.statusCode != 200) {
        throw ApiError('UNAUTHORIZED', 'Login failed', res.statusCode);
      }
      final body = (res.data as Map).cast<String, dynamic>();
      final session = (body['session'] as Map).cast<String, dynamic>();
      return LoginResult(
        accessToken: body['access_token'] as String,
        userId: session['user_id'] as String,
        nickname: (session['nickname'] as String?) ?? '(no nickname)',
        roles: ((session['roles'] as List?) ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> logout() async {
    try {
      // Server-side logout is a no-op in the alpha JWT design but we still
      // call it so the contract works once revocation is added.
      await _ref.read(dioProvider).post<dynamic>('/auth/logout');
    } catch (_) {
      // Logout never blocks the client; swallow network errors.
    }
  }
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref));
