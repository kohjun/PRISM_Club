import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/event_card/data/event_card_dto.dart';
import 'package:mobile/features/reference/data/reference_dto.dart';
import 'package:mobile/features/room/data/room_summary_dto.dart';
import 'package:mobile/features/search/data/search_repository.dart';
import 'package:mobile/features/topic_hub/data/topic_hub_dto.dart';
import 'package:mobile/features/topic_hub/data/topic_hub_repository.dart';
import 'package:mobile/features/topic_hub/ui/topic_hub_screen.dart';

// Stub destinations — render the captured route + query so the test
// can assert exactly what TopicHubScreen handed to the composer.
class _ComposerProbe extends StatelessWidget {
  const _ComposerProbe({required this.label, required this.uri});
  final String label;
  final Uri uri;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PROBE:$label'),
              Text('spaceSlug=${uri.queryParameters['spaceSlug'] ?? ''}'),
              Text('returnTo=${uri.queryParameters['returnTo'] ?? ''}'),
              Text('target_block_id=${uri.queryParameters['target_block_id'] ?? ''}'),
            ],
          ),
        ),
      );
}

TopicHubBundle _bundle() => const TopicHubBundle(
      categorySlug: 'love-content',
      categoryName: '연애',
      categoryDescription: 'desc',
      hubTitle: '연애 토픽 허브',
      hubSummary: 'summary',
      blocks: [
        KnowledgeBlockDto(
          id: 'b-1',
          blockType: 'OVERVIEW',
          title: '개요',
          body: '본문',
          sortOrder: 0,
        ),
      ],
      signals: <TopicSignalDto>[],
      relatedEvents: <EventCardDto>[],
      relatedReferences: <ReferenceDto>[],
      rooms: <RoomSummaryDto>[],
    );

Widget _appAt(String initialLocation) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/categories/:slug',
        builder: (_, st) => TopicHubScreen(
          categorySlug: st.pathParameters['slug']!,
          spaceSlug: st.uri.queryParameters['spaceSlug'],
          returnTo: st.uri.queryParameters['returnTo'],
        ),
      ),
      GoRoute(
        path: '/categories/:slug/contributions/new',
        builder: (_, st) => _ComposerProbe(label: 'CONTRIB', uri: st.uri),
      ),
      GoRoute(
        path: '/categories/:slug/rooms/new',
        builder: (_, st) => _ComposerProbe(label: 'ROOM', uri: st.uri),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      topicHubProvider.overrideWith((ref, slug) async => _bundle()),
      // Avoid the chip-row hitting real Dio.
      searchSuggestionsProvider.overrideWith(
        (ref, slug) async => const <String>[],
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pumpHub(WidgetTester tester, String at) async {
  await tester.pumpWidget(_appAt(at));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets(
      'Home-origin Hub → "정보 개선 제안" carries returnTo into contribution composer',
      (tester) async {
    await _pumpHub(
      tester,
      '/categories/love-content?returnTo=${Uri.encodeQueryComponent('/home')}',
    );

    await tester.tap(find.text('정보 개선 제안'));
    await tester.pumpAndSettle();

    expect(find.text('PROBE:CONTRIB'), findsOneWidget);
    expect(find.text('returnTo=/home'), findsOneWidget);
    expect(find.text('spaceSlug='), findsOneWidget);
    expect(find.text('target_block_id='), findsOneWidget);
  });

  testWidgets(
      'CategoryList-origin Hub → contribution composer keeps spaceSlug',
      (tester) async {
    await _pumpHub(tester, '/categories/love-content?spaceSlug=community');

    await tester.tap(find.text('정보 개선 제안'));
    await tester.pumpAndSettle();

    expect(find.text('PROBE:CONTRIB'), findsOneWidget);
    expect(find.text('spaceSlug=community'), findsOneWidget);
    expect(find.text('returnTo='), findsOneWidget);
  });

  testWidgets(
      'Knowledge-block "propose" carries returnTo + target_block_id together',
      (tester) async {
    await _pumpHub(
      tester,
      '/categories/love-content?returnTo=${Uri.encodeQueryComponent('/home')}',
    );

    // The propose button is an IconButton with tooltip '이 블록 개선 제안'
    // — find by tooltip so the test isn't tied to the icon glyph.
    final propose = find.byTooltip('이 블록 개선 제안');
    expect(propose, findsOneWidget);
    await tester.tap(propose);
    await tester.pumpAndSettle();

    expect(find.text('PROBE:CONTRIB'), findsOneWidget);
    expect(find.text('returnTo=/home'), findsOneWidget);
    expect(find.text('target_block_id=b-1'), findsOneWidget);
  });

  testWidgets(
      'Hub with external returnTo drops it before propagating to composer',
      (tester) async {
    // External URL should fail isSafeInternalRoute and never reach
    // the composer route.
    await _pumpHub(
      tester,
      '/categories/love-content?returnTo=${Uri.encodeQueryComponent('https://evil.example.com')}',
    );

    await tester.tap(find.text('정보 개선 제안'));
    await tester.pumpAndSettle();

    expect(find.text('PROBE:CONTRIB'), findsOneWidget);
    expect(find.text('returnTo='), findsOneWidget);
  });
}
