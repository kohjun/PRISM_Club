import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Current authenticated user (M13: JWT-backed).
/// Holds the access token and a minimal id/nickname snapshot. The token is
/// what authenticates every Dio request via the `dioProvider` interceptor.
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

class CurrentUserNotifier extends AsyncNotifier<CurrentUser?> {
  static const _kUserId = 'currentUser.id';
  static const _kNickname = 'currentUser.nickname';
  static const _kAccessToken = 'currentUser.accessToken';

  @override
  Future<CurrentUser?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kUserId);
    final nickname = prefs.getString(_kNickname);
    final token = prefs.getString(_kAccessToken);
    if (id == null || nickname == null || token == null) return null;
    return CurrentUser(id: id, nickname: nickname, accessToken: token);
  }

  Future<void> setUser(CurrentUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, user.id);
    await prefs.setString(_kNickname, user.nickname);
    await prefs.setString(_kAccessToken, user.accessToken);
    state = AsyncData(user);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kNickname);
    await prefs.remove(_kAccessToken);
    state = const AsyncData(null);
  }
}

final currentUserProvider =
    AsyncNotifierProvider<CurrentUserNotifier, CurrentUser?>(
        CurrentUserNotifier.new);
