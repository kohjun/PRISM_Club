import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_error.dart';
import 'package:mobile/features/event_card/data/event_card_dto.dart';
import 'package:mobile/features/event_detail/data/event_detail_dto.dart';
import 'package:mobile/features/event_detail/data/event_detail_repository.dart';
import 'package:mobile/features/event_detail/ui/event_detail_screen.dart';
import 'package:mobile/features/home/data/home_dto.dart';
import 'package:mobile/features/home/data/home_repository.dart';
import 'package:mobile/features/home/ui/home_screen.dart';
import 'package:mobile/features/notifications/data/notification_dto.dart';
import 'package:mobile/features/notifications/data/notification_repository.dart';
import 'package:mobile/features/notifications/ui/notification_screen.dart';
import 'package:mobile/features/saves/data/saved_item_dto.dart';
import 'package:mobile/features/saves/data/saves_repository.dart';
import 'package:mobile/features/saves/ui/saved_items_screen.dart';
import 'package:mobile/features/search/data/search_dto.dart';
import 'package:mobile/features/search/data/search_repository.dart';
import 'package:mobile/features/search/ui/search_screen.dart';
import 'package:mobile/features/topic_hub/data/topic_hub_repository.dart';
import 'package:mobile/features/topic_hub/ui/topic_hub_screen.dart';
import 'package:mobile/features/user_profile/data/user_follow_repository.dart';
import 'package:mobile/features/user_profile/data/user_profile_dto.dart';
import 'package:mobile/features/user_profile/data/user_profile_repository.dart';
import 'package:mobile/features/user_profile/ui/profile_screen.dart';

import 'helpers/visual_smoke.dart';

// A long Korean ApiError message — exercises the 280dp-constrained
// message Text inside ErrorView at narrow widths, and verifies the
// retry button + container don't overflow underneath it.
const _longApiErrorMessage =
    '서버가 일시적으로 응답하지 않습니다. 잠시 후 다시 시도해 주세요. '
    '문제가 계속되면 운영자에게 문의해 주세요. 한국어 라인 브레이크가 까다로워 폭이 좁아도 안전해야 합니다.';

class _StubSearchRepo implements SearchRepository {
  @override
  Future<SearchResponseDto> search({
    required String query,
    Set<String>? types,
    int? limit,
  }) async =>
      SearchResponseDto(query: query, groups: const []);

  @override
  Future<List<String>> suggestions({String? categorySlug}) async =>
      const <String>[];
}

class _StubFollowRepo implements UserFollowRepository {
  @override
  Future<UserFollowStateDto> getState(String userId) async =>
      const UserFollowStateDto(followed: false, followerCount: 0);

  @override
  Future<UserFollowStateDto> toggle(String userId) async =>
      const UserFollowStateDto(followed: true, followerCount: 1);
}

Widget _home({required Object Function() throwOrReturn}) {
  return ProviderScope(
    overrides: [
      homeBundleProvider.overrideWith((_) async {
        final r = throwOrReturn();
        if (r is HomeBundleDto) return r;
        throw r;
      }),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

HomeBundleDto _emptyHomeBundle() => const HomeBundleDto(
      unreadNotificationCount: 0,
      followedRoomUpdates: [],
      recommendedRooms: [],
      recommendedEvents: [],
      trendingPosts: [],
      activeTopicHubs: [],
      savedRecently: [],
    );

void main() {
  // ----- Home -----
  for (final size in kSmokeViewports) {
    testWidgets(
        'home EMPTY state visual smoke at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflow(tester, () async {
        await tester.pumpWidget(_home(throwOrReturn: _emptyHomeBundle));
        await tester.pump();
        await tester.pump();
      });
      expect(find.textContaining('아직 표시할 콘텐츠가 없어요'), findsOneWidget);
    });

    testWidgets(
        'home ERROR state with long ApiError message at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflow(tester, () async {
        await tester.pumpWidget(_home(throwOrReturn: () =>
            ApiError('SERVER_ERROR', _longApiErrorMessage, 503)));
        await tester.pump();
        await tester.pump();
      });
      expect(find.textContaining('서버가 일시적으로'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });
  }

  // ----- TopicHub error -----
  for (final size in kSmokeViewports) {
    testWidgets(
        'topic hub ERROR state visual smoke at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflow(tester, () async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            topicHubProvider.overrideWith(
              (ref, slug) async => throw ApiError(
                  'SERVER_ERROR', _longApiErrorMessage, 503),
            ),
          ],
          child: const MaterialApp(
            home: TopicHubScreen(categorySlug: 'love-content'),
          ),
        ));
        await tester.pump();
        await tester.pump();
      });
      expect(find.textContaining('서버가 일시적으로'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });
  }

  // ----- Search no-results -----
  for (final size in kSmokeViewports) {
    testWidgets(
        'search NO RESULTS state visual smoke at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflow(tester, () async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            searchRepositoryProvider.overrideWithValue(_StubSearchRepo()),
            searchSuggestionsProvider(null)
                .overrideWith((_) async => const <String>[]),
          ],
          child: const MaterialApp(
            home: SearchScreen(initialQuery: 'no-such-thing-xyz'),
          ),
        ));
        await tester.pump();
        // Search has a 300ms debounce + the future then resolves.
        await tester.pump(const Duration(milliseconds: 500));
      });
      expect(find.textContaining('결과가 없어요'), findsOneWidget);
    });
  }

  // ----- SavedItems empty -----
  for (final size in kSmokeViewports) {
    testWidgets(
        'saved items EMPTY state visual smoke at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflow(tester, () async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            savedItemsProvider(null).overrideWith(
              (_) async => const SavedItemListDto(items: []),
            ),
          ],
          child: const MaterialApp(home: SavedItemsScreen()),
        ));
        await tester.pump();
        await tester.pump();
      });
      expect(find.textContaining('저장한 항목이 없어요'), findsOneWidget);
    });
  }

  // ----- Notifications empty + error -----
  for (final size in kSmokeViewports) {
    testWidgets(
        'notifications EMPTY state visual smoke at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflow(tester, () async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            notificationsProvider.overrideWith(
              (_) async => const NotificationListDto(
                items: [],
                nextCursor: null,
                unreadCount: 0,
              ),
            ),
          ],
          child: const MaterialApp(home: NotificationScreen()),
        ));
        await tester.pump();
        await tester.pump();
      });
      expect(find.textContaining('새 알림이 없어요'), findsOneWidget);
    });
  }

  // ----- Profile ERROR (long message) -----
  for (final size in kSmokeViewports) {
    testWidgets(
        'profile ERROR state visual smoke at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflow(tester, () async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            userProfileProvider('u-haneul').overrideWith(
              (_) async => throw ApiError(
                  'SERVER_ERROR', _longApiErrorMessage, 503),
            ),
            userFollowRepositoryProvider.overrideWithValue(_StubFollowRepo()),
          ],
          child: const MaterialApp(
            home: ProfileScreen(userId: 'u-haneul'),
          ),
        ));
        await tester.pump();
        await tester.pump();
      });
      expect(find.textContaining('서버가 일시적으로'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });
  }

  // ----- EventDetail with empty related rooms + posts -----
  for (final size in kSmokeViewports) {
    testWidgets(
        'event detail EMPTY related state visual smoke at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflowWhileScrolling(tester, () async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            eventDetailProvider('card-1').overrideWith(
              (_) async => EventDetailBundleDto(
                eventCard: EventCardDto(
                  id: 'card-1',
                  externalEventId: 'evt-001',
                  title: 'PRISM 소개팅 미션 나이트',
                  venueName: '홍대 스튜디오',
                  region: '서울/홍대',
                  startsAt: DateTime(2026, 6, 1, 19),
                  eventStatus: 'OPEN',
                  thumbnailUrl: null,
                ),
                relatedRooms: const <RelatedRoomDto>[],
                relatedPosts: const [],
                relatedPostsNextCursor: null,
                defaultComposeRoomSlug: null,
                postCount: 0,
                roomCount: 0,
              ),
            ),
            savedItemsProvider('EVENT_CARD').overrideWith(
              (_) async => const SavedItemListDto(items: []),
            ),
          ],
          child: const MaterialApp(
            home: EventDetailScreen(cardId: 'card-1'),
          ),
        ));
        await tester.pump();
        await tester.pump();
      });
      expect(find.textContaining('아직 이 이벤트로 작성된 글이 없어요'),
          findsAtLeastNWidgets(1));
    });
  }
}
