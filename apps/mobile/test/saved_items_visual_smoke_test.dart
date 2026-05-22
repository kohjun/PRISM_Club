import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/event_card/data/event_card_dto.dart';
import 'package:mobile/features/post/data/post_dto.dart';
import 'package:mobile/features/reference/data/reference_dto.dart';
import 'package:mobile/features/saves/data/saved_item_dto.dart';
import 'package:mobile/features/saves/data/saves_repository.dart';
import 'package:mobile/features/saves/ui/saved_items_screen.dart';

import 'helpers/visual_smoke.dart';

PostDto _post(String id, String body) => PostDto(
      id: id,
      roomId: 'room-1',
      roomSlug: 'dating-event-reviews',
      roomName: '후기 방',
      author: const PostAuthorDto(
          id: 'u-haneul', nickname: '하늘 매우 긴 닉네임 후보', avatarUrl: null),
      body: body,
      status: 'VISIBLE',
      postType: 'GENERAL',
      recruitmentFields: null,
      createdAt: DateTime(2026, 5, 18),
      updatedAt: DateTime(2026, 5, 18),
      attachments: const [],
      replyCount: 3,
      likeCount: 9,
      likedByMe: false,
    );

SavedItemDto _savedPost(String id) => SavedItemDto(
      id: 'sv-$id',
      targetType: 'POST',
      targetId: id,
      savedAt: DateTime(2026, 5, 18, 10),
      postTarget: _post(id, '저장한 글 본문이 좀 길어도 카드 폭에서 깨지지 않아야 합니다. 한국어 줄바꿈 검증.'),
    );

SavedItemDto _savedReference(String id) => SavedItemDto(
      id: 'sv-$id',
      targetType: 'REFERENCE',
      targetId: id,
      savedAt: DateTime(2026, 5, 18, 11),
      referenceTarget: const ReferenceDto(
        id: 'ref-1',
        type: 'TV_SHOW',
        url: 'https://example.com/show',
        title: '환승연애 시즌2 — 저장한 레퍼런스 제목이 매우 길어도 카드가 무너지지 않아야 함',
        sourceName: 'tvN',
        thumbnailUrl: null,
        summary: '요약이 길어도 두 줄 ellipsis로 안전.',
        status: 'VISIBLE',
        sourceTier: 'TRUSTED',
      ),
    );

SavedItemDto _savedEvent(String id) => SavedItemDto(
      id: 'sv-$id',
      targetType: 'EVENT_CARD',
      targetId: id,
      savedAt: DateTime(2026, 5, 18, 12),
      eventCardTarget: EventCardDto(
        id: id,
        externalEventId: 'evt-$id',
        title: 'PRISM 소개팅 미션 나이트 — 저장한 이벤트',
        venueName: '홍대',
        region: '서울/홍대',
        startsAt: DateTime(2026, 6, 1, 19),
        eventStatus: 'OPEN',
        thumbnailUrl: null,
      ),
    );

Widget _wrap() => ProviderScope(
      overrides: [
        // null = "all types" filter, the default tab on this screen.
        savedItemsProvider(null).overrideWith(
          (_) async => SavedItemListDto(
            items: [_savedPost('p-1'), _savedReference('r-1'), _savedEvent('e-1')],
          ),
        ),
      ],
      child: const MaterialApp(home: SavedItemsScreen()),
    );

void main() {
  for (final size in kSmokeViewports) {
    testWidgets(
        'saved items visual smoke does not overflow at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      await expectNoOverflowWhileScrolling(tester, () async {
        await tester.pumpWidget(_wrap());
        await tester.pump();
        await tester.pump();
      });

      // AppBar title.
      expect(find.text('저장한 항목'), findsOneWidget);
      // Reference saved item title.
      expect(find.textContaining('환승연애 시즌2'), findsAtLeastNWidgets(1));
    });
  }
}
