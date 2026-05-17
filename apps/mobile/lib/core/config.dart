import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// API base URL — the root every Dio request is relative to.
///
/// Resolution precedence (highest first):
///   1. `--dart-define=API_BASE_URL=<value>` at compile time (always wins).
///      Production builds ship with this set to the canonical API host;
///      staging builds set it to `https://api.staging.<domain>/v1`; physical
///      devices set it to `http://<lan-ip>:3000/v1` for local testing.
///   2. Web target (`kIsWeb`) → `http://localhost:3000/v1`. The browser tab
///      reaches the host machine via loopback.
///   3. Android emulator (`Platform.isAndroid`) → `http://10.0.2.2:3000/v1`.
///      10.0.2.2 is the emulator's alias for the host machine; localhost
///      from inside an emulator would loop back to the emulator itself.
///   4. Everything else (iOS Simulator, desktop) → `http://localhost:3000/v1`.
///
/// See [resolveApiBaseUrl] for the pure form used in tests.
String get apiBaseUrl => resolveApiBaseUrl(
      compileTimeOverride: const String.fromEnvironment('API_BASE_URL'),
      isWeb: kIsWeb,
      // `Platform.isAndroid` is unsafe on web; guard with `!isWeb`.
      isAndroid: !kIsWeb && Platform.isAndroid,
    );

/// Pure resolver — same precedence as [apiBaseUrl] but takes platform
/// signals as parameters so it's exhaustively testable without touching
/// `Platform` or `kIsWeb` (both of which are global / runtime-only).
///
/// Trailing slashes on the override are stripped so subsequent Dio path
/// concatenation produces stable URLs regardless of how the operator
/// formatted the dart-define.
String resolveApiBaseUrl({
  required String compileTimeOverride,
  required bool isWeb,
  required bool isAndroid,
}) {
  final override = compileTimeOverride.trim();
  if (override.isNotEmpty) return _stripTrailingSlash(override);
  if (isWeb) return 'http://localhost:3000/v1';
  if (isAndroid) return 'http://10.0.2.2:3000/v1';
  return 'http://localhost:3000/v1';
}

String _stripTrailingSlash(String s) {
  if (s.isEmpty) return s;
  var end = s.length;
  while (end > 0 && s.codeUnitAt(end - 1) == 0x2F /* '/' */) {
    end--;
  }
  return s.substring(0, end);
}
