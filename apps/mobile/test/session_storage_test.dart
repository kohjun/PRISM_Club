import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/current_user.dart';
import 'package:mobile/core/session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory fake. Lives in the test file so production code doesn't
/// ship a third implementation that would never be exercised.
class InMemorySessionStorage implements SessionStorage {
  StoredSession? _value;

  @override
  Future<StoredSession?> load() async => _value;

  @override
  Future<void> save(StoredSession session) async {
    _value = session;
  }

  @override
  Future<void> clear() async {
    _value = null;
  }
}

void main() {
  group('SharedPrefsSessionStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns null when no session stored', () async {
      final storage = SharedPrefsSessionStorage();
      expect(await storage.load(), isNull);
    });

    test('save → load round-trips every field', () async {
      final storage = SharedPrefsSessionStorage();
      await storage.save(const StoredSession(
        id: 'u-1',
        nickname: 'tester',
        accessToken: 'fake-jwt',
      ));
      final loaded = await storage.load();
      expect(loaded, isNotNull);
      expect(loaded!.id, 'u-1');
      expect(loaded.nickname, 'tester');
      expect(loaded.accessToken, 'fake-jwt');
    });

    test('clear → load returns null', () async {
      final storage = SharedPrefsSessionStorage();
      await storage.save(const StoredSession(
        id: 'u-2',
        nickname: 'tester2',
        accessToken: 'fake-jwt-2',
      ));
      await storage.clear();
      expect(await storage.load(), isNull);
    });

    test('partial state (only some keys present) loads as null', () async {
      // Simulate a corrupted state where someone manually deleted one
      // of the three keys. The storage MUST refuse to return a half
      // session — the JWT alone without a user id would break Dio.
      SharedPreferences.setMockInitialValues({
        'currentUser.id': 'u-3',
        // nickname intentionally missing
        'currentUser.accessToken': 'fake-jwt-3',
      });
      final storage = SharedPrefsSessionStorage();
      expect(await storage.load(), isNull);
    });
  });

  group('InMemorySessionStorage (test fixture)', () {
    test('behaves like the real implementations for the contract', () async {
      final storage = InMemorySessionStorage();
      expect(await storage.load(), isNull);

      await storage.save(const StoredSession(
        id: 'u-1',
        nickname: 'tester',
        accessToken: 'fake-jwt',
      ));
      final loaded = await storage.load();
      expect(loaded?.id, 'u-1');

      await storage.clear();
      expect(await storage.load(), isNull);
    });
  });

  group('CurrentUserNotifier wired to a SessionStorage', () {
    test('build() returns null when storage is empty', () async {
      final storage = InMemorySessionStorage();
      final container = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
      ]);
      addTearDown(container.dispose);

      final user = await container.read(currentUserProvider.future);
      expect(user, isNull);
    });

    test('setUser persists to storage and restore returns it', () async {
      final storage = InMemorySessionStorage();

      // First container — login + persist.
      final c1 = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
      ]);
      await c1.read(currentUserProvider.future);
      await c1.read(currentUserProvider.notifier).setUser(const CurrentUser(
            id: 'u-1',
            nickname: 'tester',
            accessToken: 'fake-jwt',
          ));
      expect(c1.read(currentUserProvider).valueOrNull?.id, 'u-1');
      c1.dispose();

      // Second container with the SAME storage — simulates app restart.
      final c2 = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
      ]);
      addTearDown(c2.dispose);
      final restored = await c2.read(currentUserProvider.future);
      expect(restored?.id, 'u-1');
      expect(restored?.nickname, 'tester');
      expect(restored?.accessToken, 'fake-jwt');
    });

    test('signOut clears storage and resets state', () async {
      final storage = InMemorySessionStorage();
      // Pre-populate so build() resolves with a user.
      await storage.save(const StoredSession(
        id: 'u-1',
        nickname: 'tester',
        accessToken: 'fake-jwt',
      ));

      final container = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
      ]);
      addTearDown(container.dispose);

      final user = await container.read(currentUserProvider.future);
      expect(user?.id, 'u-1');

      await container.read(currentUserProvider.notifier).signOut();
      expect(container.read(currentUserProvider).valueOrNull, isNull);
      expect(await storage.load(), isNull);
    });
  });
}
