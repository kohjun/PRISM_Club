import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_error.dart';
import 'package:mobile/features/event_card/data/event_card_dto.dart';
import 'package:mobile/features/home/data/home_dto.dart';
import 'package:mobile/features/home/data/home_repository.dart';
import 'package:mobile/features/home/ui/home_screen.dart';
import 'package:mobile/features/post/data/post_dto.dart';
import 'package:mobile/features/room/data/room_summary_dto.dart';
import 'package:mobile/features/saves/data/saved_item_dto.dart';

PostDto _post(String id) => PostDto(
      id: id,
      roomId: 'room-1',
      roomSlug: 'dating-event-reviews',
      roomName: '후기 방',
      author: const PostAuthorDto(id: 'u1', nickname: 'minseo', avatarUrl: null),
      body: '팔로우 방 게시글 $id',
      status: 'VISIBLE',
      postType: 'GENERAL',
      recruitmentFields: null,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      attachments: const [],
      replyCount: 2,
      likeCount: 5,
      likedByMe: false,
    );

RoomSummaryDto _room(String slug, String name) => RoomSummaryDto(
      id: 'room-$slug',
      slug: slug,
      name: name,
      description: null,
      origin: 'OFFICIAL',
      roomType: 'EVENT_REACTION',
      ownerNickname: null,
    );


HomeBundleDto _bundleWithSections({
  List<PostDto> followedRoomUpdates = const [],
  List<RoomSummaryDto> recommendedRooms = const [],
  List<EventCardDto> recommendedEvents = const [],
  List<PostDto> trendingPosts = const [],
  List<TopicHubSummaryDto> activeTopicHubs = const [],
  List<SavedItemDto> savedRecently = const [],
}) =>
    HomeBundleDto(
      unreadNotificationCount: 0,
      followedRoomUpdates: followedRoomUpdates,
      recommendedRooms: recommendedRooms,
      recommendedEvents: recommendedEvents,
      trendingPosts: trendingPosts,
      activeTopicHubs: activeTopicHubs,
      savedRecently: savedRecently,
    );

Widget _wrap(HomeBundleDto bundle) => ProviderScope(
      overrides: [
        homeBundleProvider.overrideWith((_) async => bundle),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );

void main() {
  testWidgets(
      'renders 팔로우한 방 업데이트 section when followedRoomUpdates non-empty',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(
      _bundleWithSections(followedRoomUpdates: [_post('post-1')]),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('팔로우한 방 업데이트'), findsOneWidget);
    expect(find.textContaining('팔로우 방 게시글 post-1'), findsOneWidget);
  });

  testWidgets('renders 추천 방 section with room names', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(
      _bundleWithSections(
          recommendedRooms: [_room('fun-room', '재밌는 방'), _room('chill', '힐링 채팅')]),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('추천 방'), findsOneWidget);
    expect(find.text('재밌는 방'), findsOneWidget);
    expect(find.text('힐링 채팅'), findsOneWidget);
  });

  testWidgets('renders empty state when all sections are empty', (tester) async {
    await tester.pumpWidget(_wrap(_bundleWithSections()));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('아직 표시할 콘텐츠가 없어요'), findsOneWidget);
    expect(find.text('팔로우한 방 업데이트'), findsNothing);
    expect(find.text('추천 방'), findsNothing);
  });

  testWidgets(
      'ApiError surfaces its message and a 다시 시도 retry button',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        homeBundleProvider.overrideWith((_) async {
          throw ApiError('SERVER_ERROR', '서버에 연결할 수 없어요', 503);
        }),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('서버에 연결할 수 없어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets(
      'non-ApiError falls back to a Korean copy + retry button (no raw stack)',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        homeBundleProvider.overrideWith((_) async {
          throw Exception('lower-level details should NOT be shown to users');
        }),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('홈을 불러오지 못했어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    // Raw exception text MUST NOT be surfaced.
    expect(find.textContaining('lower-level details'), findsNothing);
  });
}
