import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/me_dto.dart';
import 'package:mobile/features/auth/data/me_repository.dart';
import 'package:mobile/features/notifications/data/notification_repository.dart';
import 'package:mobile/features/space/data/space_dto.dart';
import 'package:mobile/features/space/data/space_repository.dart';
import 'package:mobile/features/space/ui/space_list_screen.dart';

import 'helpers/visual_smoke.dart';

List<SpaceDto> _spaces() => const [
      SpaceDto(
        id: 'sp-1',
        slug: 'participant',
        name: '참가자 커뮤니티 — 긴 이름도 카드가 깨지지 않아야 함',
        audience: 'PARTICIPANT',
        accessPolicy: 'PUBLIC',
      ),
      SpaceDto(
        id: 'sp-2',
        slug: 'planner',
        name: '기획자 커뮤니티',
        audience: 'PLANNER',
        accessPolicy: 'PLANNER_ONLY',
      ),
    ];

Widget _wrap() => ProviderScope(
      overrides: [
        spaceListProvider.overrideWith((_) async => _spaces()),
        meProvider.overrideWith(
          (_) async => const MeDto(
            id: 'u-1',
            status: 'ACTIVE',
            nickname: '하늘이라는 길어도 안전한 닉네임',
            region: '서울',
            roles: <String>['VERIFIED_PLANNER'],
          ),
        ),
        unreadCountProvider.overrideWith((_) async => 12),
      ],
      child: const MaterialApp(home: SpaceListScreen()),
    );

void main() {
  for (final size in kSmokeViewports) {
    testWidgets(
        'space list visual smoke does not overflow at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflowWhileScrolling(tester, () async {
        await tester.pumpWidget(_wrap());
        await tester.pump();
        await tester.pump();
      });

      expect(find.textContaining('참가자 커뮤니티'), findsOneWidget);
      expect(find.text('기획자 커뮤니티'), findsOneWidget);
    });
  }
}
