import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A persisted login session. Only what the API absolutely needs to
/// re-authenticate on app start.
@immutable
class StoredSession {
  const StoredSession({
    required this.id,
    required this.nickname,
    required this.accessToken,
  });

  final String id;
  final String nickname;
  final String accessToken;
}

/// Storage boundary for the JWT + user snapshot.
///
/// Two production implementations:
/// - [SecureSessionStorage] — wraps `flutter_secure_storage` (Android
///   Keystore-backed `EncryptedSharedPreferences` on Android, Keychain
///   on iOS). The default on mobile.
/// - [SharedPrefsSessionStorage] — wraps `shared_preferences`. The
///   default on web; on mobile it would store the JWT in plaintext
///   under `/data/data/<pkg>/shared_prefs/`, which is the risk we're
///   walking away from.
///
/// Tests override [sessionStorageProvider] with an in-memory fake
/// (see `test/session_storage_test.dart`) so the abstraction stays
/// platform-free in unit tests.
abstract class SessionStorage {
  Future<StoredSession?> load();
  Future<void> save(StoredSession session);
  Future<void> clear();
}

class SharedPrefsSessionStorage implements SessionStorage {
  static const _kUserId = 'currentUser.id';
  static const _kNickname = 'currentUser.nickname';
  static const _kAccessToken = 'currentUser.accessToken';

  @override
  Future<StoredSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kUserId);
    final nickname = prefs.getString(_kNickname);
    final token = prefs.getString(_kAccessToken);
    if (id == null || nickname == null || token == null) return null;
    return StoredSession(id: id, nickname: nickname, accessToken: token);
  }

  @override
  Future<void> save(StoredSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, session.id);
    await prefs.setString(_kNickname, session.nickname);
    await prefs.setString(_kAccessToken, session.accessToken);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kNickname);
    await prefs.remove(_kAccessToken);
  }
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _kUserId = 'currentUser.id';
  static const _kNickname = 'currentUser.nickname';
  static const _kAccessToken = 'currentUser.accessToken';

  @override
  Future<StoredSession?> load() async {
    final id = await _storage.read(key: _kUserId);
    final nickname = await _storage.read(key: _kNickname);
    final token = await _storage.read(key: _kAccessToken);
    if (id == null || nickname == null || token == null) return null;
    return StoredSession(id: id, nickname: nickname, accessToken: token);
  }

  @override
  Future<void> save(StoredSession session) async {
    await _storage.write(key: _kUserId, value: session.id);
    await _storage.write(key: _kNickname, value: session.nickname);
    await _storage.write(key: _kAccessToken, value: session.accessToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kNickname);
    await _storage.delete(key: _kAccessToken);
  }
}

/// Provider that picks the right storage implementation for the target.
///
/// - Web: [SharedPrefsSessionStorage]. Browsers have no real keychain;
///   this is the same plaintext localStorage path the app has used
///   since M13.
/// - Everywhere else (Android, iOS, desktop): [SecureSessionStorage].
///
/// Tests override this with an in-memory fake — see
/// `test/session_storage_test.dart` for the canonical pattern.
final sessionStorageProvider = Provider<SessionStorage>((ref) {
  if (kIsWeb) return SharedPrefsSessionStorage();
  return SecureSessionStorage();
});
