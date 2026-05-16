import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stub auth identity. Replaced by JWT in phase 2 — the rest of the app only
/// cares about `id` and `nickname`.
class CurrentUser {
  const CurrentUser({required this.id, required this.nickname});
  final String id;
  final String nickname;
}

class CurrentUserNotifier extends AsyncNotifier<CurrentUser?> {
  static const _kUserId = 'currentUser.id';
  static const _kNickname = 'currentUser.nickname';

  @override
  Future<CurrentUser?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kUserId);
    final nickname = prefs.getString(_kNickname);
    if (id == null || nickname == null) return null;
    return CurrentUser(id: id, nickname: nickname);
  }

  Future<void> setUser(CurrentUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, user.id);
    await prefs.setString(_kNickname, user.nickname);
    state = AsyncData(user);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kNickname);
    state = const AsyncData(null);
  }
}

final currentUserProvider =
    AsyncNotifierProvider<CurrentUserNotifier, CurrentUser?>(CurrentUserNotifier.new);
