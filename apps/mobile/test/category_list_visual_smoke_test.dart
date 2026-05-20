import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/category/data/category_dto.dart';
import 'package:mobile/features/category/data/category_repository.dart';
import 'package:mobile/features/category/ui/category_list_screen.dart';

import 'helpers/visual_smoke.dart';

CategoryDto _cat(String slug, String name, String desc) => CategoryDto(
      id: 'cat-$slug',
      slug: slug,
      name: name,
      description: desc,
      spaceSlug: 'participant',
      spaceName: '참가자 커뮤니티',
    );

List<CategoryDto> _categories() => [
      _cat(
        'love-content',
        '연애 예능과 매칭 — 한국어 카테고리 이름이 길어도 카드 폭 안에서 안전',
        '소개팅·환승연애·매칭 콘텐츠를 함께 이야기하는 곳입니다. 설명이 길어도 카드가 무너지지 않아야 합니다.',
      ),
      _cat('party-games', '파티 게임', '오프라인 파티에서 쓰는 게임을 정리'),
    ];

Widget _wrap() => ProviderScope(
      overrides: [
        categoryListProvider('participant')
            .overrideWith((_) async => _categories()),
      ],
      child: const MaterialApp(
        home: CategoryListScreen(spaceSlug: 'participant'),
      ),
    );

void main() {
  for (final size in kSmokeViewports) {
    testWidgets(
        'category list visual smoke does not overflow at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflowWhileScrolling(tester, () async {
        await tester.pumpWidget(_wrap());
        await tester.pump();
        await tester.pump();
      });

      // CategoryCard renders names as '# <name>' — match contains.
      expect(find.textContaining('연애 예능과 매칭'), findsAtLeastNWidgets(1));
      expect(find.textContaining('파티 게임'), findsAtLeastNWidgets(1));
    });
  }
}
