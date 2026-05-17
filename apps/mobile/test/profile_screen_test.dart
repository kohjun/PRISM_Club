import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/post/data/post_dto.dart';
import 'package:mobile/features/user_profile/data/user_follow_repository.dart';
import 'package:mobile/features/user_profile/data/user_profile_dto.dart';
import 'package:mobile/features/user_profile/data/user_profile_repository.dart';
import 'package:mobile/features/user_profile/ui/profile_screen.dart';

PostDto _post(String id) => PostDto(
      id: id,
      roomId: 'room-1',
      roomSlug: 'dating-event-reviews',
      roomName: '후기 방',
      author: const PostAuthorDto(
          id: 'u-haneul', nickname: 'haneul', avatarUrl: null),
      body: '테스트 게시글 $id',
      status: 'VISIBLE',
      postType: 'GENERAL',
      recruitmentFields: null,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      attachments: const [],
      replyCount: 0,
      likeCount: 0,
      likedByMe: false,
    );

UserProfileBundleDto _bundle({
  List<String> roles = const [],
  List<PostDto> recentPosts = const [],
  bool isSelf = false,
  bool isFollowing = false,
}) =>
    UserProfileBundleDto(
      user: ProfileUserDto(
        id: 'u-haneul',
        nickname: 'haneul',
        avatarUrl: null,
        status: 'ACTIVE',
        createdAt: DateTime(2025),
      ),
      profile: const ProfileSubDto(
        bio: '놀이 기획자',
        region: '서울',
        interests: ['스왑톡'],
      ),
      roles: roles,
      counts: const ProfileCountsDto(
        postCount: 3,
        roomCount: 1,
        followerCount: 2,
        followingCount: 0,
      ),
      recentPosts: recentPosts,
      userRooms: const [],
      approvedContributions: const [],
      isSelf: isSelf,
      isFollowing: isFollowing,
    );

class _FakeFollowRepo implements UserFollowRepository {
  _FakeFollowRepo({
    this.initialFollowed = false,
    this.onToggle,
  });

  final bool initialFollowed;
  final void Function(String userId)? onToggle;

  @override
  Future<UserFollowStateDto> getState(String userId) async {
    return UserFollowStateDto(
      followed: initialFollowed,
      followerCount: initialFollowed ? 3 : 2,
    );
  }

  @override
  Future<UserFollowStateDto> toggle(String userId) async {
    onToggle?.call(userId);
    return const UserFollowStateDto(followed: true, followerCount: 3);
  }
}

Widget _wrap(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: ProfileScreen(userId: 'u-haneul')),
    );

void main() {
  testWidgets(
      'renders nickname + role badge (VERIFIED_PLANNER) when roles include it',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap([
      userProfileProvider('u-haneul')
          .overrideWith((_) async => _bundle(roles: ['VERIFIED_PLANNER'])),
      userFollowRepositoryProvider.overrideWithValue(_FakeFollowRepo()),
    ]));
    await tester.pump();
    await tester.pump();

    // AppBar + hero block both have 'haneul'; allow >= 1.
    expect(find.text('haneul'), findsAtLeastNWidgets(1));
    expect(find.text('Verified Planner'), findsOneWidget);
    expect(find.text('놀이 기획자'), findsOneWidget);
    expect(find.text('스왑톡'), findsOneWidget);
  });

  testWidgets('renders 최근 글 section when recentPosts non-empty',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap([
      userProfileProvider('u-haneul')
          .overrideWith((_) async => _bundle(recentPosts: [_post('p-1')])),
      userFollowRepositoryProvider.overrideWithValue(_FakeFollowRepo()),
    ]));
    await tester.pump();
    await tester.pump();

    expect(find.text('최근 글'), findsOneWidget);
    expect(find.textContaining('테스트 게시글 p-1'), findsOneWidget);
  });

  testWidgets('tapping 팔로우 button calls UserFollowRepository.toggle',
      (tester) async {
    String? toggledForId;

    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap([
      userProfileProvider('u-haneul').overrideWith((_) async => _bundle()),
      userFollowRepositoryProvider.overrideWithValue(_FakeFollowRepo(
        onToggle: (uid) => toggledForId = uid,
      )),
    ]));
    await tester.pump();
    await tester.pump();

    final follow = find.text('팔로우');
    expect(follow, findsOneWidget);

    await tester.tap(follow);
    await tester.pump();
    await tester.pump();

    expect(toggledForId, 'u-haneul');
  });
}
