import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Crashlytics bootstrap (P1.3).
///
/// Call from `main()` BEFORE `runApp`. Collection is gated by two checks:
///
///   1. `kDebugMode` — never report from `flutter run`, so developer crashes
///      don't pollute the staging/production console.
///   2. `--dart-define=PRISM_CRASHLYTICS_ENABLED=false` — opt-out kill
///      switch for release builds (default is enabled).
///
/// PII rules: we only call `setUserIdentifier(<uuid>)` after a successful
/// auth. Never feed nicknames, emails, phones, or post bodies into custom
/// keys — see docs/PRIVACY_DATA_INVENTORY.md.
class CrashlyticsBootstrap {
  CrashlyticsBootstrap._();

  /// Whether the build was instructed to collect crashes. Computed once at
  /// boot so the UI can show a "Crashlytics OFF" hint in the hidden ops menu
  /// during QA.
  static late final bool collectionEnabled;

  /// Wire Firebase + Crashlytics. Idempotent: safe to call twice (Firebase
  /// throws `[core/duplicate-app]` on the second `initializeApp`, which we
  /// swallow).
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (e) {
      // Duplicate-app errors happen during hot restart in dev; ignore.
      if (e.code != 'duplicate-app') rethrow;
    }

    const enabledFlag = bool.fromEnvironment(
      'PRISM_CRASHLYTICS_ENABLED',
      defaultValue: true,
    );
    collectionEnabled = !kDebugMode && enabledFlag;

    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(collectionEnabled);

    // Route every uncaught Flutter framework error to Crashlytics. The
    // `recordFlutterFatalError` helper attaches the framework context so
    // the console can group by widget tree, not by raw stack.
    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;

    // PlatformDispatcher captures the async errors Flutter framework misses
    // (e.g. unhandled Future rejections inside isolates). Returning `true`
    // tells Flutter we owned the error so it doesn't double-report.
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Bind the active session's UUID to subsequent reports. UUID only —
  /// never nickname/email/phone.
  static Future<void> bindUser(String userId) async {
    if (userId.isEmpty) return;
    await FirebaseCrashlytics.instance.setUserIdentifier(userId);
  }

  /// Clear the user identifier on sign-out.
  static Future<void> unbindUser() async {
    await FirebaseCrashlytics.instance.setUserIdentifier('');
  }

  /// Synchronously throw to verify the pipeline reaches the Crashlytics
  /// console. Wired to the hidden ops menu; never call from production
  /// code paths.
  static void throwTestException() {
    throw StateError('PRISM Crashlytics test exception');
  }
}
