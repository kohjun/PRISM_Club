import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/search/data/search_repository.dart';
import 'package:mobile/features/search/ui/search_screen.dart';

import 'helpers/visual_smoke.dart';

Widget _wrap() => ProviderScope(
      overrides: [
        searchSuggestionsProvider(null).overrideWith(
          (_) async => const [
            '환승연애',
            '소개팅 미션 — 인기 검색어 라벨이 좀 길어도 chip이 안전해야 함',
            '체크리스트',
            '파티 게임',
            '운영 노트',
          ],
        ),
      ],
      child: const MaterialApp(home: SearchScreen()),
    );

void main() {
  for (final size in kSmokeViewports) {
    testWidgets(
        'search visual smoke does not overflow at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflowWhileScrolling(tester, () async {
        await tester.pumpWidget(_wrap());
        await tester.pump();
        await tester.pump();
      });

      // Empty-query state shows the suggestion list with these chips.
      expect(find.text('인기 토픽'), findsOneWidget);
      expect(find.text('환승연애'), findsOneWidget);
    });
  }
}
