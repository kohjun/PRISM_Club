import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/event_card/data/event_card_dto.dart';
import 'package:mobile/features/event_detail/data/event_detail_dto.dart';
import 'package:mobile/features/event_detail/data/event_detail_repository.dart';
import 'package:mobile/features/event_detail/ui/event_detail_screen.dart';
import 'package:mobile/features/saves/data/saved_item_dto.dart';
import 'package:mobile/features/saves/data/saves_repository.dart'
    show savedItemsProvider;

import 'helpers/visual_smoke.dart';

EventCardDto _card() => EventCardDto(
      id: 'card-1',
      externalEventId: 'evt-001',
      title: 'PRISM 소개팅 미션 나이트 — 매우 긴 한국어 제목이 들어가도 헤더가 깨지지 않아야 함',
      venueName: '홍대 스튜디오 — 긴 장소명',
      region: '서울/홍대',
      startsAt: DateTime(2026, 5, 25, 19),
      eventStatus: 'OPEN',
      thumbnailUrl: null,
    );

RelatedRoomDto _room(String slug, String name, {String relation = 'PIN'}) =>
    RelatedRoomDto(
      id: 'room-$slug',
      slug: slug,
      name: name,
      origin: 'OFFICIAL',
      roomType: 'EVENT_REACTION',
      ownerNickname: null,
      relation: relation,
    );

EventDetailBundleDto _populatedBundle() => EventDetailBundleDto(
      eventCard: _card(),
      relatedRooms: [
        _room('dating-event-reviews', '소개팅·매칭 이벤트 후기 — 긴 방 이름'),
        _room('event-staff', '이벤트 스태프 모집'),
      ],
      relatedPosts: const [],
      relatedPostsNextCursor: null,
      defaultComposeRoomSlug: 'dating-event-reviews',
      postCount: 0,
      roomCount: 2,
    );

Widget _wrap(EventDetailBundleDto bundle) => ProviderScope(
      overrides: [
        eventDetailProvider('card-1').overrideWith((_) async => bundle),
        savedItemsProvider('EVENT_CARD').overrideWith(
            (_) async => const SavedItemListDto(items: [])),
      ],
      child: const MaterialApp(home: EventDetailScreen(cardId: 'card-1')),
    );

void main() {
  for (final size in kSmokeViewports) {
    testWidgets(
        'event detail visual smoke does not overflow at ${size.width.toInt()}dp',
        (tester) async {
      setSmokeViewport(tester, size);
      // expectNoOverflowWhileScrolling drags through hero → date card →
      // related rooms → related posts sliver, so overflow below the
      // fold is exercised, not just the initial viewport.
      await expectNoOverflowWhileScrolling(tester, () async {
        await tester.pumpWidget(_wrap(_populatedBundle()));
        await tester.pump();
        await tester.pump();
      });

      // Event title appears in AppBar + hero card.
      expect(
        find.textContaining('PRISM 소개팅 미션 나이트'),
        findsAtLeastNWidgets(1),
      );
      // Compose CTA.
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  }
}
