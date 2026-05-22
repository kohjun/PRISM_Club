import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dio_provider.dart';

/// Thin wrapper over `POST/DELETE /v1/me/device-tokens`. Best-effort by
/// design: a registration failure must NOT block sign-in, so all calls
/// swallow errors and log in debug mode.
class DeviceTokenRepository {
  DeviceTokenRepository(this._dio);

  final Dio _dio;

  Future<void> register({
    required String token,
    String? appVersion,
    String? deviceModel,
    String? locale,
  }) async {
    try {
      await _dio.post(
        '/me/device-tokens',
        data: {
          'token': token,
          'platform': _platformName(),
          'provider': 'FCM',
          if (appVersion != null) 'app_version': appVersion,
          if (deviceModel != null) 'device_model': deviceModel,
          if (locale != null) 'locale': locale,
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[device-token] register failed: $e');
    }
  }

  Future<void> revoke(String token) async {
    if (token.isEmpty) return;
    try {
      await _dio.delete('/me/device-tokens/$token');
    } catch (e) {
      if (kDebugMode) debugPrint('[device-token] revoke failed: $e');
    }
  }

  String _platformName() {
    if (kIsWeb) return 'WEB';
    if (Platform.isAndroid) return 'ANDROID';
    if (Platform.isIOS) return 'IOS';
    return 'WEB';
  }
}

final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>(
  (ref) => DeviceTokenRepository(ref.watch(dioProvider)),
);
