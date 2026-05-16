import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/search/data/search_dto.dart';
import 'package:mobile/features/search/ui/widgets/search_result_tile.dart';

SearchHitDto _hit({
  required String type,
  required String title,
  String snippet = '',
  Map<String, dynamic> context = const {},
}) =>
    SearchHitDto(
      type: type,
      id: 'id-1',
      title: title,
      snippet: snippet,
      context: context,
    );

// Wraps the tile in a minimal MaterialApp.router so context.go inside the tile
// does not throw even though we don't actually verify navigation here.
Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => child),
      GoRoute(path: '/categories/:slug', builder: (_, _) => const Placeholder()),
      GoRoute(path: '/rooms/:slug', builder: (_, _) => const Placeholder()),
      GoRoute(path: '/posts/:id', builder: (_, _) => const Placeholder()),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('renders topic_hub title and Topic Hub context line',
      (tester) async {
    await tester.pumpWidget(_wrap(SearchResultTile(
      hit: _hit(
        type: SearchEntityType.topicHub,
        title: '연애 예능과 오프라인 매칭',
        snippet: '핵심 정보와 데이터 신호',
        context: {'category_slug': 'love-content'},
      ),
    )));
    expect(find.text('연애 예능과 오프라인 매칭'), findsOneWidget);
    expect(find.text('핵심 정보와 데이터 신호'), findsOneWidget);
    expect(find.byIcon(Icons.topic_outlined), findsOneWidget);
    expect(find.textContaining('Topic Hub'), findsOneWidget);
  });

  testWidgets('renders post context as 글 · room · author', (tester) async {
    await tester.pumpWidget(_wrap(SearchResultTile(
      hit: _hit(
        type: SearchEntityType.post,
        title: '소개팅 미션 후기',
        snippet: '처음엔 어색했는데…',
        context: {
          'post_id': 'p1',
          'room_slug': 'dating-event-reviews',
          'room_name': '소개팅/매칭 이벤트 후기',
          'author_nickname': '민서',
        },
      ),
    )));
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.textContaining('소개팅/매칭 이벤트 후기'), findsOneWidget);
    expect(find.textContaining('민서'), findsOneWidget);
  });

  testWidgets('renders room context with origin + owner', (tester) async {
    await tester.pumpWidget(_wrap(SearchResultTile(
      hit: _hit(
        type: SearchEntityType.room,
        title: '환승연애식 오프라인 토크 게임',
        context: {
          'room_slug': 'swap-style-talk-game',
          'category_slug': 'love-content',
          'origin': 'USER',
          'owner_nickname': 'haneul',
        },
      ),
    )));
    expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
    expect(find.textContaining('유저 생성 방'), findsOneWidget);
    expect(find.textContaining('haneul'), findsOneWidget);
  });

  testWidgets('renders event_card with completed badge in context line',
      (tester) async {
    await tester.pumpWidget(_wrap(SearchResultTile(
      hit: _hit(
        type: SearchEntityType.eventCard,
        title: 'PRISM 소개팅 미션 나이트',
        context: {
          'external_event_id': 'evt-001',
          'venue_name': '홍대 스튜디오',
          'region': '서울/홍대',
          'starts_at': '2026-04-25T19:00:00.000Z',
          'event_status': 'COMPLETED',
        },
      ),
    )));
    expect(find.byIcon(Icons.event), findsOneWidget);
    expect(find.textContaining('완료'), findsOneWidget);
    expect(find.textContaining('서울/홍대'), findsOneWidget);
  });

  testWidgets('renders reference with source name', (tester) async {
    await tester.pumpWidget(_wrap(SearchResultTile(
      hit: _hit(
        type: SearchEntityType.reference,
        title: '환승연애 대화 구조 분석',
        context: {
          'reference_type': 'TV_SHOW',
          'url': 'https://example.com/r',
          'source_name': '블로그 정리',
        },
      ),
    )));
    expect(find.byIcon(Icons.link), findsOneWidget);
    expect(find.textContaining('블로그 정리'), findsOneWidget);
  });
}
