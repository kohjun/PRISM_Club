import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/me_dto.dart';
import 'package:mobile/features/auth/data/me_repository.dart';
import 'package:mobile/features/notifications/data/notification_repository.dart';
import 'package:mobile/features/space/data/space_dto.dart';
import 'package:mobile/features/space/data/space_repository.dart';
import 'package:mobile/features/space/ui/space_list_screen.dart';

const _participant = SpaceDto(
  id: 'aa000000-0000-0000-0000-000000000001',
  slug: 'participant',
  name: '참가자 커뮤니티',
  audience: 'PARTICIPANT',
  accessPolicy: 'PUBLIC',
);

const _planner = SpaceDto(
  id: 'aa000000-0000-0000-0000-000000000002',
  slug: 'planner',
  name: '기획자 커뮤니티',
  audience: 'PLANNER',
  accessPolicy: 'PLANNER_ONLY',
);

MeDto _me({required List<String> roles, String id = 'u1'}) => MeDto(
      id: id,
      status: 'ACTIVE',
      nickname: 'tester',
      region: '서울',
      roles: roles,
    );

Widget _wrap({
  required List<Override> overrides,
}) =>
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: SpaceListScreen()),
    );

void main() {
  testWidgets('non-planner sees lock dialog when tapping planner card',
      (tester) async {
    await tester.pumpWidget(_wrap(
      overrides: [
        spaceListProvider.overrideWith((_) async => [_participant, _planner]),
        meProvider.overrideWith((_) async => _me(roles: ['MEMBER'])),
        unreadCountProvider.overrideWith((_) async => 0),
      ],
    ));
    await tester.pump(); // resolve futures
    await tester.pump();

    expect(find.text('기획자 커뮤니티'), findsOneWidget);
    expect(find.text('스태프 모집, 운영 노트 · 인증 필요'), findsOneWidget);

    await tester.tap(find.text('기획자 커뮤니티'));
    await tester.pumpAndSettle();

    expect(find.text('인증된 기획자만 입장할 수 있어요'), findsOneWidget);
    expect(find.textContaining('PRISM과 협업하는'), findsOneWidget);
    expect(find.textContaining('권한 신청은 운영자'), findsOneWidget);
  });

  testWidgets('bell badge shows count when unreadCount > 0', (tester) async {
    await tester.pumpWidget(_wrap(
      overrides: [
        spaceListProvider.overrideWith((_) async => [_participant]),
        meProvider.overrideWith((_) async => _me(roles: ['MEMBER'])),
        unreadCountProvider.overrideWith((_) async => 2),
      ],
    ));
    await tester.pump();
    await tester.pump();

    // The Badge widget should have label text '2'
    expect(find.text('2'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
  });

  testWidgets('verified planner sees unlocked subtitle (no lock state)',
      (tester) async {
    await tester.pumpWidget(_wrap(
      overrides: [
        spaceListProvider.overrideWith((_) async => [_participant, _planner]),
        meProvider.overrideWith(
          (_) async => _me(roles: ['VERIFIED_PLANNER']),
        ),
        unreadCountProvider.overrideWith((_) async => 0),
      ],
    ));
    await tester.pump();
    await tester.pump();

    // Locked subtitle should NOT appear; unlocked planner subtitle should.
    expect(find.text('스태프 모집, 운영 노트 · 인증 필요'), findsNothing);
    expect(find.text('스태프 모집, 운영 노트, 콘텐츠 기획 토론'), findsOneWidget);
    // The lock dialog must not be on screen on initial render.
    expect(find.text('인증된 기획자만 입장할 수 있어요'), findsNothing);
  });
}
