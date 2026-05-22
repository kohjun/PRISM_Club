import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'fcm_background.dart';

/// FCM lifecycle owner (P1.2).
///
/// Call `initialize()` from `main()` AFTER Firebase has been initialised
/// (the Crashlytics bootstrap already does that). The function is
/// idempotent so hot-restart in dev doesn't double-register listeners.
///
/// Token registration with the server (`POST /me/device-tokens`) is NOT
/// owned by this class — that crosses into the auth-aware layer (Dio
/// session, current user). The auth controller calls
/// `FcmBootstrap.currentToken` after a successful login and binds it,
/// then calls `FcmBootstrap.attachAuthBridge(onTokenRefresh: …)` so we
/// can push refreshed tokens up the same channel.
class FcmBootstrap {
  FcmBootstrap._();

  static bool _initialized = false;
  static bool _permissionGranted = false;
  static String? _currentToken;

  /// True after `Permission.notification` returned granted/limited.
  static bool get permissionGranted => _permissionGranted;

  /// The most recently observed FCM token. Null until `initialize()`
  /// completes the first `getToken()` call, or if Play Services are
  /// unavailable (emulator without Google APIs).
  static String? get currentToken => _currentToken;

  static void Function(String token)? _onTokenRefreshCallback;
  static void Function(RemoteMessage message)? _onForegroundCallback;
  static void Function(String deepLink)? _onTapCallback;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Background handler must be registered BEFORE any other messaging
    // call. The handler is a top-level function in fcm_background.dart
    // — required because it runs in a separate isolate.
    FirebaseMessaging.onBackgroundMessage(
      prismFirebaseMessagingBackgroundHandler,
    );

    // Foreground presentation options are mostly iOS-side; Android
    // shows heads-up notifications based on the channel importance.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android 13+ runtime permission. permission_handler is the
    // cross-platform wrapper; on lower API levels the request is a
    // no-op and returns granted.
    final status = await Permission.notification.request();
    _permissionGranted = status.isGranted || status.isLimited;
    if (!_permissionGranted) {
      if (kDebugMode) debugPrint('[fcm] notification permission denied');
      // We still subscribe to listeners — if the user grants the
      // permission later via system settings, FCM starts delivering
      // and our handlers are already attached.
    }

    try {
      _currentToken = await FirebaseMessaging.instance.getToken();
      if (kDebugMode) {
        debugPrint(
          '[fcm] token: ${_currentToken == null ? "null" : "${_currentToken!.substring(0, 12)}…"}',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[fcm] getToken failed: $e');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      _currentToken = t;
      _onTokenRefreshCallback?.call(t);
    });

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageTapped);

    // Cold-start tap — the OS killed the process and the user opened
    // the app via a notification. We replay the tap once.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _onMessageTapped(initial);
  }

  /// Bridge to the auth-aware layer. Pass callbacks that should fire
  /// for token rotation / incoming messages / notification taps. Called
  /// once near the top of the widget tree (e.g. from a Riverpod
  /// listener on the auth provider) and overrides previous callbacks.
  static void attachAuthBridge({
    void Function(String token)? onTokenRefresh,
    void Function(RemoteMessage message)? onForegroundMessage,
    void Function(String deepLink)? onNotificationTap,
  }) {
    _onTokenRefreshCallback = onTokenRefresh;
    _onForegroundCallback = onForegroundMessage;
    _onTapCallback = onNotificationTap;
  }

  static void _onForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[fcm-fg] type=${message.data['type']}');
    }
    _onForegroundCallback?.call(message);
  }

  static void _onMessageTapped(RemoteMessage message) {
    final deepLink = message.data['deep_link'];
    if (deepLink is String && deepLink.isNotEmpty) {
      _onTapCallback?.call(deepLink);
    }
  }
}
