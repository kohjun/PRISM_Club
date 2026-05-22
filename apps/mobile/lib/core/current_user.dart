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
    this.refreshToken,
  });

  final String id;
  final String nickname;
  final String accessToken;
  final String? refreshToken;

  CurrentUser copyWithAccessToken(String newAccessToken) {
    return CurrentUser(
      id: id,
      nickname: nickname,
      accessToken: newAccessToken,
      refreshToken: refreshToken,
    );
  }
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
      refreshToken: stored.refreshToken,
    );
  }

  Future<void> setUser(CurrentUser user) async {
    final storage = ref.read(sessionStorageProvider);
    await storage.save(StoredSession(
      id: user.id,
      nickname: user.nickname,
      accessToken: user.accessToken,
      refreshToken: user.refreshToken,
    ));
    state = AsyncData(user);
  }

  /// Update the access token only — preserves refresh token + identity.
  /// Used by the Dio 401 interceptor after a successful /auth/refresh.
  Future<void> updateAccessToken(String newAccessToken) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.copyWithAccessToken(newAccessToken);
    final storage = ref.read(sessionStorageProvider);
    await storage.save(StoredSession(
      id: updated.id,
      nickname: updated.nickname,
      accessToken: updated.accessToken,
      refreshToken: updated.refreshToken,
    ));
    state = AsyncData(updated);
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
