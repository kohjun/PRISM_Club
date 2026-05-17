import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ops/data/ops_dto.dart';
import 'package:mobile/features/ops/data/ops_repository.dart';
import 'package:mobile/features/ops/ui/ops_dashboard_screen.dart';

OpsSummaryDto _sample() => OpsSummaryDto(
      pendingContributions: 2,
      openReports: 1,
      recruitmentOpen: 2,
      recruitmentTotal: 3,
      recentUserCount: 1,
      recentUsers: [
        OpsUserRow(
          id: 'u1',
          nickname: 'newperson',
          createdAt: DateTime(2026),
        ),
      ],
      recentRoomCount: 1,
      recentRooms: [
        OpsRoomRow(
          id: 'r1',
          slug: 'new-room',
          name: '새로운 방',
          createdAt: DateTime(2026),
        ),
      ],
      recentPostCount: 0,
      recentPosts: const [],
    );

void main() {
  testWidgets('dashboard renders all card values and recent users', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        opsSummaryProvider.overrideWith((_) async => _sample()),
      ],
      child: const MaterialApp(home: OpsDashboardScreen()),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('운영 대시보드'), findsOneWidget);
    expect(find.text('대기 중인 기여'), findsOneWidget);
    expect(find.text('열린 신고'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // pending contributions value
    expect(find.text('2/3'), findsOneWidget); // recruitment ratio
    expect(find.text('newperson'), findsOneWidget);
    expect(find.text('새로운 방'), findsOneWidget);
  });
}
