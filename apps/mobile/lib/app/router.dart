import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/current_user.dart';
import '../features/auth/ui/login_picker_screen.dart';
import '../features/category/ui/category_list_screen.dart';
import '../features/knowledge/ui/contribution_composer_screen.dart';
import '../features/knowledge/ui/curation_detail_screen.dart';
import '../features/knowledge/ui/curation_queue_screen.dart';
import '../features/knowledge/ui/my_contributions_screen.dart';
import '../features/post/ui/post_composer_screen.dart';
import '../features/post/ui/post_detail_screen.dart';
import '../features/post/ui/recruitment_composer_screen.dart';
import '../features/search/ui/search_screen.dart';
import '../features/room/ui/room_creator_screen.dart';
import '../features/room/ui/room_timeline_screen.dart';
import '../features/space/ui/space_list_screen.dart';
import '../features/topic_hub/ui/topic_hub_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final auth = ref.read(currentUserProvider);
      // Don't redirect until the AsyncNotifier resolves (initial SharedPreferences read).
      if (auth.isLoading) return null;

      final loggedIn = auth.valueOrNull != null;
      final goingToLogin = state.matchedLocation == '/login';

      if (!loggedIn && !goingToLogin) return '/login';
      if (loggedIn && goingToLogin) return '/spaces';
      return null;
    },
    refreshListenable: _RouterRefresh(ref),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/spaces'),
      GoRoute(path: '/login', builder: (_, _) => const LoginPickerScreen()),
      GoRoute(path: '/spaces', builder: (_, _) => const SpaceListScreen()),
      GoRoute(
        path: '/spaces/:spaceSlug/categories',
        builder: (_, st) => CategoryListScreen(
          spaceSlug: st.pathParameters['spaceSlug']!,
        ),
      ),
      GoRoute(
        path: '/categories/:categorySlug',
        builder: (_, st) => TopicHubScreen(
          categorySlug: st.pathParameters['categorySlug']!,
        ),
      ),
      GoRoute(
        path: '/categories/:categorySlug/rooms/new',
        builder: (_, st) => RoomCreatorScreen(
          categorySlug: st.pathParameters['categorySlug']!,
        ),
      ),
      GoRoute(
        path: '/rooms/:roomSlug',
        builder: (_, st) => RoomTimelineScreen(
          roomSlug: st.pathParameters['roomSlug']!,
        ),
      ),
      GoRoute(
        path: '/rooms/:roomSlug/compose',
        builder: (_, st) => PostComposerScreen(
          roomSlug: st.pathParameters['roomSlug']!,
        ),
      ),
      GoRoute(
        path: '/rooms/:roomSlug/compose-recruitment',
        builder: (_, st) => RecruitmentComposerScreen(
          roomSlug: st.pathParameters['roomSlug']!,
        ),
      ),
      GoRoute(
        path: '/posts/:postId',
        builder: (_, st) => PostDetailScreen(
          postId: st.pathParameters['postId']!,
        ),
      ),
      // Milestone 2: knowledge contributions
      GoRoute(
        path: '/categories/:categorySlug/contributions/new',
        builder: (_, st) => ContributionComposerScreen(
          categorySlug: st.pathParameters['categorySlug']!,
          initialTargetBlockId: st.uri.queryParameters['target_block_id'],
        ),
      ),
      GoRoute(path: '/me/contributions', builder: (_, _) => const MyContributionsScreen()),
      GoRoute(path: '/curate', builder: (_, _) => const CurationQueueScreen()),
      GoRoute(
        path: '/curate/:id',
        builder: (_, st) => CurationDetailScreen(
          contributionId: st.pathParameters['id']!,
        ),
      ),
      // Milestone 3: unified search
      GoRoute(
        path: '/search',
        builder: (_, st) => SearchScreen(
          initialQuery: st.uri.queryParameters['q'],
          categorySlug: st.uri.queryParameters['categorySlug'],
        ),
      ),
    ],
  );
});

/// Bridges Riverpod state changes to GoRouter's `refreshListenable`.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _sub = _ref.listen<AsyncValue<CurrentUser?>>(
      currentUserProvider,
      (_, _) => notifyListeners(),
    );
  }

  final Ref _ref;
  // ignore: unused_field
  late final ProviderSubscription<AsyncValue<CurrentUser?>> _sub;
}
