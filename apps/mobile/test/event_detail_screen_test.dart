import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/event_card/data/event_card_dto.dart';
import 'package:mobile/features/event_detail/data/event_detail_dto.dart';
import 'package:mobile/features/event_detail/data/event_detail_repository.dart';
import 'package:mobile/features/event_detail/ui/event_detail_screen.dart';
import 'package:mobile/features/saves/data/saved_item_dto.dart';
import 'package:mobile/features/saves/data/saves_repository.dart' show savedItemsProvider;

EventCardDto _card() => EventCardDto(
      id: 'card-1',
      externalEventId: 'evt-001',
      title: 'PRISM 소개팅 미션 나이트',
      venueName: '홍대 스튜디오',
      region: '서울/홍대',
      startsAt: DateTime(2026, 4, 25, 19),
      eventStatus: 'COMPLETED',
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

EventDetailBundleDto _bundle({
  List<RelatedRoomDto> rooms = const [],
  int postCount = 0,
  String? defaultSlug,
}) =>
    EventDetailBundleDto(
      eventCard: _card(),
      relatedRooms: rooms,
      relatedPosts: const [],
      relatedPostsNextCursor: null,
      defaultComposeRoomSlug: defaultSlug,
      postCount: postCount,
      roomCount: rooms.length,
    );

Widget _wrap(Widget child, {required EventDetailBundleDto bundle}) =>
    ProviderScope(
      overrides: [
        eventDetailProvider('card-1').overrideWith((_) async => bundle),
        // Prevent real Dio calls from the save state watcher
        savedItemsProvider('EVENT_CARD').overrideWith(
            (_) async => const SavedItemListDto(items: [])),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('renders title, hero card, room tile, and empty-state copy',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const EventDetailScreen(cardId: 'card-1'),
      bundle: _bundle(
        rooms: [_room('dating-event-reviews', '소개팅/매칭 이벤트 후기')],
        defaultSlug: 'dating-event-reviews',
      ),
    ));
    await tester.pump();
    await tester.pump();

    // AppBar title — there are usually two text widgets with the same
    // string (AppBar + hero card), so allow >= 1.
    expect(
      find.text('PRISM 소개팅 미션 나이트'),
      findsAtLeastNWidgets(1),
    );

    // Related rooms section.
    expect(find.text('관련 방 (1)'), findsOneWidget);
    expect(find.text('소개팅/매칭 이벤트 후기'), findsOneWidget);

    // Related posts empty state.
    expect(find.text('관련 글 (0)'), findsOneWidget);
    expect(find.textContaining('아직 이 이벤트로 작성된 글이 없어요'), findsOneWidget);

    // CTA exists and is enabled.
    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.onPressed, isNotNull);
  });

  testWidgets('CTA is disabled when no related rooms AND no default slug',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const EventDetailScreen(cardId: 'card-1'),
      bundle: _bundle(),
    ));
    await tester.pump();
    await tester.pump();

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.onPressed, isNull);
  });

  testWidgets('CTA is enabled when default slug exists (fallback) even with zero rooms',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const EventDetailScreen(cardId: 'card-1'),
      bundle: _bundle(defaultSlug: 'dating-event-reviews'),
    ));
    await tester.pump();
    await tester.pump();

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.onPressed, isNotNull);
  });
}
