import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/topic_hub/data/similar_hub_dto.dart';
import 'package:mobile/features/topic_hub/data/similar_hub_repository.dart';
import 'package:mobile/features/topic_hub/ui/widgets/similar_topic_hub_strip.dart';

SimilarHubDto _hub({
  String id = 'hub-1',
  String slug = 'recruit-content',
  String title = '모집 콘텐츠 허브',
  int contributors = 3,
  int rooms = 0,
}) =>
    SimilarHubDto(
      id: id,
      slug: slug,
      title: title,
      categorySlug: slug,
      score: 0.42,
      sharedContributorCount: contributors,
      sharedRoomCount: rooms,
    );

Widget _wrap(Widget child, {required List<SimilarHubDto> items}) =>
    ProviderScope(
      overrides: [
        similarHubsProvider('love-content').overrideWith((_) async => items),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('hides itself when there are no similar hubs', (tester) async {
    await tester.pumpWidget(_wrap(
      const SimilarTopicHubStrip(hubSlug: 'love-content'),
      items: const [],
    ));
    await tester.pump();
    expect(find.text('이 Hub와 비슷한 Hub'), findsNothing);
    expect(find.byKey(const Key('similar-hub-recruit-content')), findsNothing);
  });

  testWidgets('renders a card for each similar hub with the title',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const SimilarTopicHubStrip(hubSlug: 'love-content'),
      items: [
        _hub(slug: 'recruit-content', title: '모집 콘텐츠 허브', contributors: 3),
        _hub(slug: 'dating-game', title: '데이팅 게임', contributors: 1),
      ],
    ));
    await tester.pump();
    expect(find.text('이 Hub와 비슷한 Hub'), findsOneWidget);
    expect(find.text('모집 콘텐츠 허브'), findsOneWidget);
    expect(find.text('데이팅 게임'), findsOneWidget);
    expect(find.byKey(const Key('similar-hub-recruit-content')), findsOneWidget);
    expect(find.byKey(const Key('similar-hub-dating-game')), findsOneWidget);
  });

  testWidgets('reason chip prefers contributor count when both are set',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const SimilarTopicHubStrip(hubSlug: 'love-content'),
      items: [_hub(contributors: 4, rooms: 2)],
    ));
    await tester.pump();
    expect(find.text('공통 기여자 4명'), findsOneWidget);
    expect(find.text('공통 방 2개'), findsNothing);
  });

  testWidgets('reason chip falls back to room count when contributors are 0',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const SimilarTopicHubStrip(hubSlug: 'love-content'),
      items: [_hub(contributors: 0, rooms: 3)],
    ));
    await tester.pump();
    expect(find.text('공통 방 3개'), findsOneWidget);
  });

  testWidgets('reason chip hides when both signals are zero',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const SimilarTopicHubStrip(hubSlug: 'love-content'),
      items: [_hub(contributors: 0, rooms: 0)],
    ));
    await tester.pump();
    expect(find.text('공통 기여자 0명'), findsNothing);
    expect(find.text('공통 방 0개'), findsNothing);
    // The card itself still renders (the strip wouldn't ship a row with
    // no signals in practice — backend filters at MIN_SCORE — but the
    // widget shouldn't crash if it does).
    expect(find.text('모집 콘텐츠 허브'), findsOneWidget);
  });
}
