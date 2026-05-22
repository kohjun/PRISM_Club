import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'current_user.dart';

/// One shared Dio. Re-reads `currentUserProvider` on every request via the
/// interceptor, so switching user invalidates without rebuilding the Dio.
///
/// P1.1+: 401 responses on non-auth endpoints kick off a single
/// `/auth/refresh` round-trip; on success we update the access token in
/// `currentUserProvider` and retry the original request. On failure we
/// sign the user out and surface the 401 so the router can land on
/// `/login`.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      // Don't throw on 4xx — let repositories decide what to do.
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final user = ref.read(currentUserProvider).valueOrNull;
        if (user != null) {
          if (user.accessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer ${user.accessToken}';
          }
          // Keep X-User-Id for tests / smoke that still use it.
          options.headers['X-User-Id'] = user.id;
        }
        handler.next(options);
      },
      onResponse: (response, handler) async {
        // Auto-refresh on 401 — but never for auth endpoints themselves
        // (signup / login / refresh / logout) so we don't recurse.
        if (response.statusCode == 401 &&
            !_isAuthEndpoint(response.requestOptions.path) &&
            // Avoid double refresh for the retry probe itself.
            response.requestOptions.extra['__retried__'] != true) {
          final refreshed = await _tryRefresh(ref);
          if (refreshed) {
            try {
              // Re-issue with the new access token.
              final retryOptions = response.requestOptions
                ..extra['__retried__'] = true;
              final fresh = ref.read(currentUserProvider).valueOrNull;
              if (fresh != null) {
                retryOptions.headers['Authorization'] =
                    'Bearer ${fresh.accessToken}';
              }
              final retried = await dio.fetch(retryOptions);
              return handler.resolve(retried);
            } catch (_) {
              // Fall through to the original 401 response.
            }
          } else {
            // Refresh failed — sign out so the router redirects to /login.
            await ref
                .read(currentUserProvider.notifier)
                .signOut()
                .catchError((_) {});
          }
        }
        handler.next(response);
      },
    ),
  );

  ref.onDispose(() => dio.close(force: true));
  return dio;
});

bool _isAuthEndpoint(String path) {
  return path.startsWith('/auth/');
}

/// Attempt a refresh. Uses a raw `Dio` without our interceptors to
/// guarantee no recursion through this provider's own onResponse hook.
/// Returns true when the access token in `currentUserProvider` has been
/// rotated successfully.
Future<bool> _tryRefresh(Ref ref) async {
  final user = ref.read(currentUserProvider).valueOrNull;
  final refreshToken = user?.refreshToken;
  if (user == null || refreshToken == null || refreshToken.isEmpty) {
    return false;
  }
  try {
    final raw = Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final res = await raw.post<dynamic>(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    raw.close(force: true);
    if (res.statusCode != 200 || res.data is! Map) return false;
    final body = (res.data as Map).cast<String, dynamic>();
    final newAccess = body['access_token'] as String?;
    final newRefresh =
        (body['refresh_token'] as String?) ?? refreshToken;
    if (newAccess == null || newAccess.isEmpty) return false;

    await ref.read(currentUserProvider.notifier).setUser(
          CurrentUser(
            id: user.id,
            nickname: user.nickname,
            accessToken: newAccess,
            refreshToken: newRefresh,
          ),
        );
    return true;
  } catch (_) {
    return false;
  }
}
