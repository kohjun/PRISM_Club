import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_storage.dart';

/// Current authenticated user (M13: JWT-backed).
/// Holds the access token and a minimal id/nickname snapshot. The token is
/// what authenticates every Dio request via the `dioProvider` interceptor.
@immutable
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.nickname,
    required this.accessToken,
  });

  final String id;
  final String nickname;
  final String accessToken;
}

/// Persists the session via [SessionStorage] so storage is platform-
/// appropriate (Keychain / EncryptedSharedPreferences on mobile,
/// localStorage on web) without callers caring which.
class CurrentUserNotifier extends AsyncNotifier<CurrentUser?> {
  @override
  Future<CurrentUser?> build() async {
    final storage = ref.read(sessionStorageProvider);
    final stored = await storage.load();
    if (stored == null) return null;
    return CurrentUser(
      id: stored.id,
      nickname: stored.nickname,
      accessToken: stored.accessToken,
    );
  }

  Future<void> setUser(CurrentUser user) async {
    final storage = ref.read(sessionStorageProvider);
    await storage.save(StoredSession(
      id: user.id,
      nickname: user.nickname,
      accessToken: user.accessToken,
    ));
    state = AsyncData(user);
  }

  Future<void> signOut() async {
    final storage = ref.read(sessionStorageProvider);
    await storage.clear();
    state = const AsyncData(null);
  }
}

final currentUserProvider =
    AsyncNotifierProvider<CurrentUserNotifier, CurrentUser?>(
        CurrentUserNotifier.new);
