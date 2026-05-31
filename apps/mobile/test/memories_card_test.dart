import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/memories/data/memories_dto.dart';
import 'package:mobile/features/memories/data/memories_repository.dart';
import 'package:mobile/features/memories/ui/memories_screen.dart';
import 'package:mobile/features/memories/ui/widgets/memories_card.dart';

MemoryItemDto _item({
  String kind = 'ROOM_FOLLOW',
  int yearsAgo = 1,
  String title = '소개팅 후기 방',
  String subtitle = '1년 전 오늘 이 방을 팔로우했어요',
  String deepLink = '/rooms/dating-event-reviews',
}) =>
    MemoryItemDto(
      kind: kind,
      yearsAgo: yearsAgo,
      actedAt: '2025-03-15T08:00:00.000Z',
      title: title,
      subtitle: subtitle,
      deepLink: deepLink,
    );

Widget _wrap(Widget child, {required MemoriesDto data}) => ProviderScope(
      overrides: [
        todayMemoriesProvider.overrideWith((_) async => data),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('MemoriesCard', () {
    testWidgets('hides itself when there are no memories', (tester) async {
      await tester.pumpWidget(_wrap(
        const MemoriesCard(),
        data: const MemoriesDto(date: '2026-03-15', items: []),
      ));
      await tester.pump();
      expect(find.byKey(const Key('memories-card')), findsNothing);
      expect(find.text('오늘의 기록'), findsNothing);
    });

    testWidgets('renders lead memory + "외 N건" when multiple', (tester) async {
      await tester.pumpWidget(_wrap(
        const MemoriesCard(),
        data: MemoriesDto(
          date: '2026-03-15',
          items: [
            _item(title: '소개팅 후기 방'),
            _item(
              kind: 'EVENT_RSVP',
              yearsAgo: 2,
              title: '미션 나이트',
              subtitle: '2년 전 오늘 이 이벤트에 관심을 보였어요',
              deepLink: '/events/e1',
            ),
          ],
        ),
      ));
      await tester.pump();
      expect(find.byKey(const Key('memories-card')), findsOneWidget);
      expect(find.text('오늘의 기록'), findsOneWidget);
      expect(find.text('소개팅 후기 방'), findsOneWidget);
      expect(find.text('외 1건 더 보기'), findsOneWidget);
    });

    testWidgets('single memory shows no "외 N건" footer', (tester) async {
      await tester.pumpWidget(_wrap(
        const MemoriesCard(),
        data: MemoriesDto(date: '2026-03-15', items: [_item()]),
      ));
      await tester.pump();
      expect(find.byKey(const Key('memories-card')), findsOneWidget);
      expect(find.textContaining('외'), findsNothing);
    });
  });

  group('MemoriesScreen', () {
    testWidgets('renders a tile per memory with kind-keyed rows',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const MemoriesScreen(),
        data: MemoriesDto(
          date: '2026-03-15',
          items: [
            _item(kind: 'ROOM_FOLLOW', yearsAgo: 1),
            _item(
              kind: 'CONTRIBUTION_APPROVED',
              yearsAgo: 2,
              title: '개요 블록',
              subtitle: '2년 전 오늘 이 지식 기여가 승인됐어요',
              deepLink: '/categories/love-content',
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('오늘의 기록'), findsOneWidget); // AppBar
      expect(find.byKey(const Key('memory-ROOM_FOLLOW-1')), findsOneWidget);
      expect(
        find.byKey(const Key('memory-CONTRIBUTION_APPROVED-2')),
        findsOneWidget,
      );
      expect(find.text('개요 블록'), findsOneWidget);
    });

    testWidgets('empty state shows the encouragement copy', (tester) async {
      await tester.pumpWidget(_wrap(
        const MemoriesScreen(),
        data: const MemoriesDto(date: '2026-03-15', items: []),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('오늘 떠오를 기록이 아직 없어요'), findsOneWidget);
    });
  });
}
