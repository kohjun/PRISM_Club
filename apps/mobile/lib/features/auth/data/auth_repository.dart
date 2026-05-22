import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../core/dio_provider.dart';
import 'dev_user_dto.dart';

/// Login response shape. `refreshToken` is non-null for email / Kakao
/// logins; the legacy dev login (`POST /auth/login {user_id}`) also
/// returns one after P1.1 since the server unifies all paths through
/// `issueTokenPairForUser`.
class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.nickname,
    required this.roles,
  });
  final String accessToken;
  final String? refreshToken;
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

  /// Passwordless dev login. Only available when the server has
  /// ALLOW_DEV_LOGIN=1; otherwise the API returns 410 GONE and the
  /// client should fall back to the email path.
  Future<LoginResult> login(String userId) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/auth/login',
        data: {'user_id': userId},
      );
      if (res.statusCode != 200) {
        throw ApiError('UNAUTHORIZED', 'Login failed', res.statusCode);
      }
      return _parseLoginResult(res.data as Map);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// P1.1 email signup. Creates a User + Profile in one server-side
  /// transaction and returns a fresh access/refresh pair.
  Future<LoginResult> signupWithEmail({
    required String email,
    required String password,
    required String nickname,
  }) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/auth/signup',
        data: {
          'email': email,
          'password': password,
          'nickname': nickname,
        },
      );
      if (res.statusCode != 200) {
        throw ApiError.fromResponseBody(
          res.data,
          fallbackCode: 'SIGNUP_FAILED',
          status: res.statusCode,
        );
      }
      return _parseLoginResult(res.data as Map);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// P1.1 email login.
  Future<LoginResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/auth/login/email',
        data: {'email': email, 'password': password},
      );
      if (res.statusCode != 200) {
        throw ApiError.fromResponseBody(
          res.data,
          fallbackCode: 'LOGIN_FAILED',
          status: res.statusCode,
        );
      }
      return _parseLoginResult(res.data as Map);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// P1.1 refresh. Rotates the refresh token (the server marks the
  /// presented one revoked and returns a brand-new pair on the same
  /// family). Reuse of a revoked token triggers full-family revocation
  /// server-side; the caller will see a 401 and should sign out.
  Future<LoginResult> refresh(String refreshToken) async {
    try {
      final res = await _ref.read(dioProvider).post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      if (res.statusCode != 200) {
        throw ApiError('REFRESH_FAILED', 'Refresh failed', res.statusCode);
      }
      return _parseLoginResult(res.data as Map);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  /// Revoke a single refresh token server-side. Fire-and-forget; never
  /// blocks the client.
  Future<void> logout({String? refreshToken}) async {
    try {
      await _ref.read(dioProvider).post<dynamic>(
        '/auth/logout',
        data: {
          if (refreshToken != null && refreshToken.isNotEmpty)
            'refresh_token': refreshToken,
        },
      );
    } catch (_) {
      // Logout never blocks the client; swallow network errors.
    }
  }

  /// Revoke every refresh token for the active user (logout-everywhere).
  /// Requires a valid access token in the Authorization header.
  Future<void> logoutEverywhere() async {
    try {
      await _ref.read(dioProvider).post<dynamic>(
        '/auth/logout',
        data: {'all_devices': true},
      );
    } catch (_) {
      // Best effort.
    }
  }

  LoginResult _parseLoginResult(Map body) {
    final map = body.cast<String, dynamic>();
    final session = (map['session'] as Map).cast<String, dynamic>();
    return LoginResult(
      accessToken: map['access_token'] as String,
      refreshToken: map['refresh_token'] as String?,
      userId: session['user_id'] as String,
      nickname: (session['nickname'] as String?) ?? '(no nickname)',
      roles: ((session['roles'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref));
