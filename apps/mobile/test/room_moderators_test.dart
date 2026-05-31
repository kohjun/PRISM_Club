import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/room/data/room_role_dto.dart';
import 'package:mobile/features/room/data/room_role_repository.dart';
import 'package:mobile/features/room/ui/room_moderators_screen.dart';

RoomRoleDto _mod(String userId, String nickname) => RoomRoleDto(
      userId: userId,
      nickname: nickname,
      role: 'MODERATOR',
      grantedAt: '2026-05-20T00:00:00.000Z',
    );

Widget _wrap(List<RoomRoleDto> roles) => ProviderScope(
      overrides: [
        roomRolesProvider('swap-style-talk-game')
            .overrideWith((_) async => roles),
      ],
      child: const MaterialApp(
        home: RoomModeratorsScreen(slug: 'swap-style-talk-game'),
      ),
    );

void main() {
  testWidgets('lists current moderators with a revoke action',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _mod('u-minseo', '민서'),
      _mod('u-coral', '코랄'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('모더레이터 관리'), findsOneWidget); // AppBar
    expect(find.byKey(const Key('moderator-u-minseo')), findsOneWidget);
    expect(find.byKey(const Key('moderator-u-coral')), findsOneWidget);
    expect(find.byKey(const Key('revoke-u-minseo')), findsOneWidget);
    expect(find.text('민서'), findsOneWidget);
  });

  testWidgets('empty state shows the encouragement copy', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 지정된 모더레이터가 없어요'), findsOneWidget);
  });

  testWidgets('search field is present for adding moderators',
      (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moderator-search-field')), findsOneWidget);
  });

  testWidgets('non-moderator roles are filtered out of the list',
      (tester) async {
    await tester.pumpWidget(_wrap([
      _mod('u-minseo', '민서'),
      const RoomRoleDto(
        userId: 'u-member',
        nickname: '일반멤버',
        role: 'MEMBER',
        grantedAt: '2026-05-20T00:00:00.000Z',
      ),
    ]));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('moderator-u-minseo')), findsOneWidget);
    expect(find.byKey(const Key('moderator-u-member')), findsNothing);
  });
}
