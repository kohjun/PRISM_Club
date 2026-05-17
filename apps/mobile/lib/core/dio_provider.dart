import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'current_user.dart';

/// One shared Dio. Re-reads `currentUserProvider` on every request via the
/// interceptor, so switching user invalidates without rebuilding the Dio.
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
    ),
  );

  ref.onDispose(() => dio.close(force: true));
  return dio;
});
