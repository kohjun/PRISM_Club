import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/event_card/data/event_card_dto.dart';
import 'package:mobile/features/home/data/home_dto.dart';
import 'package:mobile/features/home/data/home_repository.dart';
import 'package:mobile/features/home/ui/home_screen.dart';
import 'package:mobile/features/post/data/post_dto.dart';
import 'package:mobile/features/room/data/room_summary_dto.dart';

import 'helpers/visual_smoke.dart';

PostDto _post(
  String id,
  String body, {
  List<PostAttachmentDto> attachments = const [],
}) =>
    PostDto(
      id: id,
      roomId: 'room-1',
      roomSlug: 'dating-event-reviews',
      roomName: '소개팅·매칭 이벤트 후기 — 본문이 길어도 카드가 무너지지 않아야 함',
      author: const PostAuthorDto(
          id: 'u-haneul', nickname: '하늘 매우 긴 닉네임 후보', avatarUrl: null),
      body: body,
      status: 'VISIBLE',
      postType: 'GENERAL',
      recruitmentFields: null,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      attachments: attachments,
      replyCount: 12,
      likeCount: 87,
      likedByMe: false,
    );

PostAttachmentDto _eventAttachment(String id) => PostAttachmentDto(
      id: 'att-$id',
      attachmentType: 'EVENT_CARD',
      target: _event(id, 'PRISM EVENT — 첨부된 이벤트 카드 제목이 매우 길어도 안전해야 함'),
      sortOrder: 0,
    );

RoomSummaryDto _room(String slug, String name) => RoomSummaryDto(
      id: 'room-$slug',
      slug: slug,
      name: name,
      description: '오프라인 이벤트 후기와 매칭 팁을 나누는 방. 설명이 길어도 한 줄 ellipsis 처리.',
      origin: 'OFFICIAL',
      roomType: 'EVENT_REACTION',
      ownerNickname: null,
    );

EventCardDto _event(String id, String title) => EventCardDto(
      id: id,
      externalEventId: 'evt-$id',
      title: title,
      venueName: '홍대 스튜디오 — 길어도 안전',
      region: '서울/홍대',
      startsAt: DateTime(2026, 6, 15, 19),
      eventStatus: 'OPEN',
      thumbnailUrl: null,
    );

HomeBundleDto _populatedBundle() => HomeBundleDto(
      unreadNotificationCount: 3,
      followedRoomUpdates: [
        // First post: attached event card. The horizontal post strip
        // renders PostCardWidget(compact: true), which suppresses the
        // attachments block — if a regression flips that off, this
        // fixture pushes the card past its 224dp container and the
        // smoke test catches the overflow.
        _post(
          'p-1',
          '팔로우한 방의 첫 글입니다. 본문이 매우 길어서 좁은 360dp 폭에서 잘려야 하지 '
          '카드가 깨지면 안 됩니다. 한국어는 줄바꿈이 까다로워서 더 주의가 필요해요.',
          attachments: [_eventAttachment('attached-evt')],
        ),
        _post('p-2', '두 번째 글.'),
      ],
      recommendedRooms: [
        _room('fun-room', '오늘의 추천 방 — 텍스트가 길어도 깨지지 않아야 함'),
        _room('chill', '힐링 채팅방'),
      ],
      recommendedEvents: [
        _event('e-1', 'PRISM 소개팅 미션 나이트 — 매우 긴 제목이 들어가도 overflow 없어야 함'),
      ],
      trendingPosts: [_post('t-1', '인기 글 본문 미리보기.')],
      activeTopicHubs: [
        TopicHubSummaryDto(
          id: 'hub-1',
          categorySlug: 'love-content',
          title: '연애 예능과 오프라인 매칭 — 긴 제목',
          summary: '오늘의 핵심 정보 미리보기.',
          blockCount: 5,
          updatedAt: DateTime(2026, 5, 18),
        ),
      ],
      savedRecently: const [],
    );

Widget _wrap(HomeBundleDto bundle) => ProviderScope(
      overrides: [
        homeBundleProvider.overrideWith((_) async => bundle),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );

void main() {
  for (final size in kSmokeViewports) {
    testWidgets(
        'home visual smoke does not overflow at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflow(tester, () async {
        await tester.pumpWidget(_wrap(_populatedBundle()));
        await tester.pump();
        await tester.pump();
      });

      // Smoke assertion — at least one of the headline sections rendered.
      // We don't pin to a specific text because copy can shift; instead
      // confirm the screen advanced past loading by finding the first
      // section header it would render in production.
      expect(find.text('팔로우한 방 업데이트'), findsOneWidget);
    });
  }
}
