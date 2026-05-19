import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/topic_hub/data/topic_hub_repository.dart';
import 'package:mobile/features/topic_hub/ui/topic_hub_screen.dart';

// Probe pages — each just renders a unique marker text so the test
// can assert "we landed here" without needing the real screen wired up.
class _Probe extends StatelessWidget {
  const _Probe(this.marker);
  final String marker;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(marker)));
}

Widget _appAt(String initialLocation) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const _Probe('HOME')),
      GoRoute(path: '/spaces', builder: (_, _) => const _Probe('SPACES')),
      GoRoute(
        path: '/spaces/:spaceSlug/categories',
        builder: (_, st) =>
            _Probe('CATS:${st.pathParameters['spaceSlug']}'),
      ),
      GoRoute(
        path: '/categories/:categorySlug',
        builder: (_, st) => TopicHubScreen(
          categorySlug: st.pathParameters['categorySlug']!,
          spaceSlug: st.uri.queryParameters['spaceSlug'],
          returnTo: st.uri.queryParameters['returnTo'],
        ),
      ),
      GoRoute(path: '/me/contributions',
          builder: (_, _) => const _Probe('MY_CONTRIBUTIONS')),
      GoRoute(
        path: '/search',
        builder: (_, st) {
          final q = st.uri.queryParameters['q'] ?? '';
          return _Probe('SEARCH:$q');
        },
      ),
    ],
  );

  // Make the topicHubProvider error out for any slug so TopicHubScreen
  // renders its error state (the AppBar — including the back button —
  // still renders, which is all we need for these tests).
  return ProviderScope(
    overrides: [
      topicHubProvider.overrideWith(
        (ref, slug) => Future.error(StateError('stubbed for back test')),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pumpAndTapBack(WidgetTester tester, String at) async {
  await tester.pumpWidget(_appAt(at));
  // Let the error future settle so the body renders error state; the
  // AppBar back button is present immediately either way.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));

  final back = find.byTooltip('뒤로');
  expect(back, findsOneWidget,
      reason: 'back button should be present in the AppBar');
  await tester.tap(back);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home-origin Topic Hub → back goes to /home (not /spaces)',
      (tester) async {
    await _pumpAndTapBack(
      tester,
      '/categories/love-content?returnTo=${Uri.encodeQueryComponent('/home')}',
    );
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('SPACES'), findsNothing);
  });

  testWidgets(
      'CategoryList-origin Topic Hub → back goes to /spaces/<slug>/categories',
      (tester) async {
    await _pumpAndTapBack(tester, '/categories/love-content?spaceSlug=community');
    expect(find.text('CATS:community'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    expect(find.text('SPACES'), findsNothing);
  });

  testWidgets('Topic Hub with no context → back falls back to /home',
      (tester) async {
    // No returnTo, no spaceSlug — last-resort fallback should be /home,
    // not /spaces (the old behavior that prompted this PR).
    await _pumpAndTapBack(tester, '/categories/love-content');
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('SPACES'), findsNothing);
  });

  testWidgets('Topic Hub ignores external returnTo (drops to fallback)',
      (tester) async {
    // Open-redirect probe — returnTo points off-domain. The screen
    // should drop it and fall back to /home.
    await _pumpAndTapBack(
      tester,
      '/categories/love-content?returnTo=${Uri.encodeQueryComponent('https://evil.example.com')}',
    );
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('Search-origin Topic Hub → back goes to /search with query',
      (tester) async {
    await _pumpAndTapBack(
      tester,
      '/categories/love-content?returnTo=${Uri.encodeQueryComponent('/search?q=love')}',
    );
    expect(find.text('SEARCH:love'), findsOneWidget);
  });

  testWidgets('returnTo wins over spaceSlug when both present',
      (tester) async {
    // returnTo is the more-specific origin signal, so it takes priority
    // over a fallback spaceSlug from an earlier deep link.
    await _pumpAndTapBack(
      tester,
      '/categories/love-content'
      '?spaceSlug=community'
      '&returnTo=${Uri.encodeQueryComponent('/me/contributions')}',
    );
    expect(find.text('MY_CONTRIBUTIONS'), findsOneWidget);
    expect(find.text('CATS:community'), findsNothing);
  });
}
