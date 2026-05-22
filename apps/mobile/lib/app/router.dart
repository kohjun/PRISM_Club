import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/current_user.dart';
import '../features/auth/ui/login_picker_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/signup_screen.dart';
import '../features/category/ui/category_list_screen.dart';
import '../features/event_detail/ui/event_detail_screen.dart';
import '../features/knowledge/ui/block_revision_history_screen.dart';
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
import '../features/home/ui/home_shell_screen.dart';
import '../features/notifications/ui/notification_screen.dart';
import '../features/notifications/ui/notification_settings_screen.dart';
import '../features/saves/ui/saved_items_screen.dart';
import '../features/topic_hub/ui/topic_hub_screen.dart';
import '../features/moderation/ui/moderation_detail_screen.dart';
import '../features/moderation/ui/moderation_queue_screen.dart';
import '../features/moderation/ui/my_reports_screen.dart';
import '../features/ops/ui/ops_dashboard_screen.dart';
import '../features/user_profile/ui/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final auth = ref.read(currentUserProvider);
      // Don't redirect until the AsyncNotifier resolves (initial SharedPreferences read).
      if (auth.isLoading) return null;

      final loggedIn = auth.valueOrNull != null;
      final matched = state.matchedLocation;
      final goingToAuthRoute = matched == '/login' ||
          matched == '/signup' ||
          matched == '/dev/login';

      if (!loggedIn && !goingToAuthRoute) return '/login';
      if (loggedIn && goingToAuthRoute) return '/home';
      return null;
    },
    refreshListenable: _RouterRefresh(ref),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/home'),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      // Dev-only persona picker. Only compiled into the bundle when the
      // `--dart-define=PRISM_DEV_LOGIN=true` flag is set; release builds
      // omit the route entirely.
      if (kPrismDevLoginEnabled)
        GoRoute(
          path: '/dev/login',
          builder: (_, _) => const LoginPickerScreen(),
        ),
      GoRoute(path: '/home', builder: (_, _) => const HomeShellScreen()),
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
          spaceSlug: st.uri.queryParameters['spaceSlug'],
          returnTo: st.uri.queryParameters['returnTo'],
        ),
      ),
      GoRoute(
        path: '/categories/:categorySlug/rooms/new',
        builder: (_, st) => RoomCreatorScreen(
          categorySlug: st.pathParameters['categorySlug']!,
          spaceSlug: st.uri.queryParameters['spaceSlug'],
          returnTo: st.uri.queryParameters['returnTo'],
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
          initialEventCardId:
              st.uri.queryParameters['attach_event_card_id'],
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
          spaceSlug: st.uri.queryParameters['spaceSlug'],
          returnTo: st.uri.queryParameters['returnTo'],
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
      // P2.1: knowledge block revision history timeline.
      GoRoute(
        path: '/knowledge-blocks/:blockId/revisions',
        builder: (_, st) => BlockRevisionHistoryScreen(
          blockId: st.pathParameters['blockId']!,
        ),
      ),
      // Milestone 5: event detail
      GoRoute(
        path: '/events/:cardId',
        builder: (_, st) => EventDetailScreen(
          cardId: st.pathParameters['cardId']!,
        ),
      ),
      // Milestone 6: notifications + saves
      GoRoute(path: '/me/notifications', builder: (_, _) => const NotificationScreen()),
      // P1.2: notification preference settings (push + per-type toggles).
      GoRoute(
        path: '/me/notifications/settings',
        builder: (_, _) => const NotificationSettingsScreen(),
      ),
      GoRoute(path: '/me/saves', builder: (_, _) => const SavedItemsScreen()),
      // Milestone 8: user profile
      GoRoute(
        path: '/users/:id',
        builder: (_, st) => ProfileScreen(userId: st.pathParameters['id']!),
      ),
      // Milestone 9: moderation
      GoRoute(path: '/me/reports', builder: (_, _) => const MyReportsScreen()),
      GoRoute(
          path: '/admin/reports',
          builder: (_, _) => const ModerationQueueScreen()),
      GoRoute(
        path: '/admin/reports/:id',
        builder: (_, st) =>
            ModerationDetailScreen(id: st.pathParameters['id']!),
      ),
      // Milestone 11: ops dashboard
      GoRoute(path: '/admin/ops', builder: (_, _) => const OpsDashboardScreen()),
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
