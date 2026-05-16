import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// API base URL — depends on platform.
///
/// - Web / iOS simulator: `localhost` reaches the host.
/// - Android emulator: needs `10.0.2.2` to reach the host.
///
/// Override at compile time with `--dart-define=API_BASE_URL=...` (real
/// device, staging, etc.).
String get apiBaseUrl {
  const override = String.fromEnvironment('API_BASE_URL');
  if (override.isNotEmpty) return override;

  if (kIsWeb) {
    return 'http://localhost:3000/v1';
  }
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:3000/v1';
  }
  return 'http://localhost:3000/v1';
}
