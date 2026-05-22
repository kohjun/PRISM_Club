import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/auth/data/dev_user_dto.dart';
import 'package:mobile/features/auth/ui/login_picker_screen.dart';

import 'helpers/visual_smoke.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.users);
  final List<DevUserDto> users;

  @override
  Future<List<DevUserDto>> listDevUsers() async => users;

  @override
  Future<LoginResult> login(String userId) async =>
      throw UnimplementedError();

  @override
  Future<LoginResult> loginWithEmail({
    required String email,
    required String password,
  }) async =>
      throw UnimplementedError();

  @override
  Future<LoginResult> signupWithEmail({
    required String email,
    required String password,
    required String nickname,
  }) async =>
      throw UnimplementedError();

  @override
  Future<LoginResult> refresh(String refreshToken) async =>
      throw UnimplementedError();

  @override
  Future<void> logout({String? refreshToken}) async =>
      throw UnimplementedError();

  @override
  Future<void> logoutEverywhere() async => throw UnimplementedError();
}

Widget _wrap() => ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(const [
          DevUserDto(id: 'u-1', nickname: '하늘 — 긴 닉네임이라도 타일이 안전해야 함'),
          DevUserDto(id: 'u-2', nickname: 'joon'),
          DevUserDto(id: 'u-3', nickname: 'minseo'),
        ])),
      ],
      child: const MaterialApp(home: LoginPickerScreen()),
    );

void main() {
  for (final size in kSmokeViewports) {
    testWidgets(
        'login picker visual smoke does not overflow at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflowWhileScrolling(tester, () async {
        await tester.pumpWidget(_wrap());
        await tester.pump();
        await tester.pump();
      });

      // First user tile renders with the long nickname.
      expect(find.textContaining('하늘'), findsAtLeastNWidgets(1));
      expect(find.text('joon'), findsOneWidget);
    });
  }
}
