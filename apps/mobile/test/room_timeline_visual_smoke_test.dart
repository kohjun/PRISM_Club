import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/me_dto.dart';
import 'package:mobile/features/auth/data/me_repository.dart';
import 'package:mobile/features/post/data/post_dto.dart';
import 'package:mobile/features/post/data/post_repository.dart';
import 'package:mobile/features/room/data/follow_repository.dart';
import 'package:mobile/features/room/data/room_detail_dto.dart';
import 'package:mobile/features/room/data/room_repository.dart';
import 'package:mobile/features/room/ui/room_timeline_screen.dart';

import 'helpers/visual_smoke.dart';

PostDto _post(String id, String body) => PostDto(
      id: id,
      roomId: 'room-1',
      roomSlug: 'dating-event-reviews',
      roomName: '소개팅·매칭 이벤트 후기',
      author: const PostAuthorDto(
          id: 'u-haneul', nickname: '하늘 매우 긴 닉네임', avatarUrl: null),
      body: body,
      status: 'VISIBLE',
      postType: 'GENERAL',
      recruitmentFields: null,
      createdAt: DateTime(2026, 5, 18),
      updatedAt: DateTime(2026, 5, 18),
      attachments: const [],
      replyCount: 5,
      likeCount: 12,
      likedByMe: false,
    );

RoomDetailDto _roomDetail() => const RoomDetailDto(
      id: 'room-1',
      slug: 'dating-event-reviews',
      name: '소개팅·매칭 이벤트 후기 — 긴 이름도 잘려야 함',
      description:
          '오프라인 매칭 이벤트 후기와 운영 노트를 나누는 방. 긴 설명이 들어와도 헤더가 깨지지 않아야 합니다.',
      rules: null,
      origin: 'OFFICIAL',
      roomType: 'EVENT_REACTION',
      ownerId: 'u-haneul',
      ownerNickname: 'haneul',
      pins: [],
      postCount: 42,
    );

class _FakeFollowRepo implements FollowRepository {
  @override
  Future<FollowStateDto> getState(String roomSlug) async =>
      const FollowStateDto(followed: false, followerCount: 7);

  @override
  Future<FollowStateDto> toggle(String roomSlug) async =>
      const FollowStateDto(followed: true, followerCount: 8);
}

Widget _wrap() => ProviderScope(
      overrides: [
        roomDetailProvider('dating-event-reviews')
            .overrideWith((_) async => _roomDetail()),
        timelineProvider('dating-event-reviews').overrideWith(
          (_) async => TimelinePage(
            items: [
              _post('p-1',
                  '첫 글 본문. 매우 긴 한국어 게시글이 좁은 360dp 폭에서도 깔끔히 잘리고 카드가 무너지지 않아야 합니다.'),
              _post('p-2', '두 번째 글.'),
            ],
            nextCursor: null,
          ),
        ),
        meProvider.overrideWith(
          (_) async => const MeDto(
            id: 'u-me',
            status: 'ACTIVE',
            nickname: 'me',
            region: '서울',
            roles: <String>[],
          ),
        ),
        followRepositoryProvider.overrideWithValue(_FakeFollowRepo()),
      ],
      child: const MaterialApp(
        home: RoomTimelineScreen(roomSlug: 'dating-event-reviews'),
      ),
    );

void main() {
  for (final size in kSmokeViewports) {
    testWidgets(
        'room timeline visual smoke does not overflow at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflow(tester, () async {
        await tester.pumpWidget(_wrap());
        await tester.pump();
        await tester.pump();
      });

      // Room name in AppBar.
      expect(find.textContaining('소개팅·매칭 이벤트 후기'), findsAtLeastNWidgets(1));
      // FAB.
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  }
}
