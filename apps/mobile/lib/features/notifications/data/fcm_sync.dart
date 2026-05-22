import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/current_user.dart';
import '../../../core/push/fcm_bootstrap.dart';
import 'device_token_repository.dart';

/// Glues `FcmBootstrap` (push lifecycle) to the auth-aware layer.
///
/// Activated by `ref.watch(fcmSyncProvider)` at the top of the widget
/// tree. Responsibilities:
///
///   1. When the current user changes (sign-in, account switch), register
///      the active FCM token against the new user.
///   2. When the user signs out, revoke the token server-side so pushes
///      stop reaching that device until they sign in again.
///   3. When FCM rotates the token (`onTokenRefresh`), re-register under
///      the active user.
///   4. When the OS delivers a notification tap, route the in-app
///      destination via `routerProvider`.
final fcmSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<CurrentUser?>>(currentUserProvider, (prev, next) {
    final prevUser = prev?.valueOrNull;
    final nextUser = next.valueOrNull;
    final token = FcmBootstrap.currentToken;
    if (token == null) return;

    if (nextUser != null &&
        (prevUser == null || prevUser.id != nextUser.id)) {
      // Sign-in or account switch.
      ref.read(deviceTokenRepositoryProvider).register(token: token);
    }
    if (nextUser == null && prevUser != null) {
      // Sign-out — revoke the active token so the previous user stops
      // receiving pushes intended for the new occupant.
      ref.read(deviceTokenRepositoryProvider).revoke(token);
    }
  });

  FcmBootstrap.attachAuthBridge(
    onTokenRefresh: (token) {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        ref.read(deviceTokenRepositoryProvider).register(token: token);
      }
    },
    onNotificationTap: (deepLink) {
      final router = ref.read(routerProvider);
      router.go(deepLink);
    },
  );
});
