import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Background message handler — required by Android when the app is fully
/// terminated and an FCM data-payload arrives. Runs in a separate isolate
/// so it MUST be a top-level (or `static`) function with the
/// `@pragma('vm:entry-point')` annotation so the Flutter VM keeps it
/// accessible from native code via tree-shaken release builds.
///
/// We intentionally keep the body minimal: no DB calls, no shared
/// services. Anything beyond logging would require re-initialising the
/// app's DI container, which is expensive and unreliable in the
/// background-isolate context. The downstream effects (timeline refresh,
/// notification badge counts) all run when the user taps the
/// notification and the app comes back to the foreground.
@pragma('vm:entry-point')
Future<void> prismFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    debugPrint('[fcm-bg] ${message.messageId} type=${message.data['type']}');
  }
}
