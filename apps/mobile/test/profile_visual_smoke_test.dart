import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/post/data/post_dto.dart';
import 'package:mobile/features/user_profile/data/user_follow_repository.dart';
import 'package:mobile/features/user_profile/data/user_profile_dto.dart';
import 'package:mobile/features/user_profile/data/user_profile_repository.dart';
import 'package:mobile/features/user_profile/ui/profile_screen.dart';

import 'helpers/visual_smoke.dart';

PostDto _post(String id, String body) => PostDto(
      id: id,
      roomId: 'room-1',
      roomSlug: 'dating-event-reviews',
      roomName: '후기 방',
      author: const PostAuthorDto(
          id: 'u-haneul', nickname: 'haneul', avatarUrl: null),
      body: body,
      status: 'VISIBLE',
      postType: 'GENERAL',
      recruitmentFields: null,
      createdAt: DateTime(2026, 5, 18),
      updatedAt: DateTime(2026, 5, 18),
      attachments: const [],
      replyCount: 1,
      likeCount: 4,
      likedByMe: false,
    );

UserProfileBundleDto _bundle() => UserProfileBundleDto(
      user: ProfileUserDto(
        id: 'u-haneul',
        nickname: '하늘 — 길어도 헤더가 안전해야 함',
        avatarUrl: null,
        status: 'ACTIVE',
        createdAt: DateTime(2025, 8, 1),
      ),
      profile: const ProfileSubDto(
        bio: '놀이 기획자. 본문이 좀 길어도 hero 블록이 무너지지 않아야 합니다. '
            '한국어 줄바꿈은 까다로워서 충분히 길게 검증합니다.',
        region: '서울',
        interests: ['스왑톡', '연애 예능', '오프라인 매칭', '운영 노트'],
      ),
      roles: const ['VERIFIED_PLANNER'],
      counts: const ProfileCountsDto(
        postCount: 28,
        roomCount: 4,
        followerCount: 142,
        followingCount: 31,
      ),
      recentPosts: [
        _post('p-1',
            '최근 글 본문 — 좁은 폭에서도 잘려야 하고 카드는 무너지지 않아야 합니다.'),
      ],
      userRooms: const [],
      approvedContributions: const [],
      isSelf: false,
      isFollowing: false,
    );

class _FakeFollowRepo implements UserFollowRepository {
  @override
  Future<UserFollowStateDto> getState(String userId) async =>
      const UserFollowStateDto(followed: false, followerCount: 142);

  @override
  Future<UserFollowStateDto> toggle(String userId) async =>
      const UserFollowStateDto(followed: true, followerCount: 143);
}

Widget _wrap() => ProviderScope(
      overrides: [
        userProfileProvider('u-haneul').overrideWith((_) async => _bundle()),
        userFollowRepositoryProvider.overrideWithValue(_FakeFollowRepo()),
      ],
      child: const MaterialApp(home: ProfileScreen(userId: 'u-haneul')),
    );

void main() {
  for (final size in kSmokeViewports) {
    testWidgets(
        'profile visual smoke does not overflow at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflow(tester, () async {
        await tester.pumpWidget(_wrap());
        await tester.pump();
        await tester.pump();
      });

      // Bio (data-state anchor inside the hero block).
      expect(find.textContaining('놀이 기획자'), findsOneWidget);
      // Follow CTA.
      expect(find.text('팔로우'), findsOneWidget);
    });
  }
}
