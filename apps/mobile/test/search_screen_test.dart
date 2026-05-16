import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/search/data/search_repository.dart';
import 'package:mobile/features/search/ui/search_screen.dart';

void main() {
  testWidgets('empty query shows popular topic suggestions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchSuggestionsProvider(null).overrideWith((_) async => [
                '환승연애',
                '소개팅 미션',
                '체크리스트',
              ]),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pump(); // resolve the FutureProvider

    expect(find.text('인기 토픽'), findsOneWidget);
    expect(find.text('환승연애'), findsOneWidget);
    expect(find.text('소개팅 미션'), findsOneWidget);
    expect(find.text('체크리스트'), findsOneWidget);
  });

  testWidgets('type filter exposes 전체 + all entity chips', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchSuggestionsProvider(null).overrideWith((_) async => const []),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('전체'), findsOneWidget);
    expect(find.text('Topic Hub'), findsOneWidget);
    expect(find.text('방'), findsOneWidget);
    expect(find.text('글'), findsOneWidget);
    expect(find.text('이벤트'), findsOneWidget);
    expect(find.text('레퍼런스'), findsOneWidget);
  });
}
