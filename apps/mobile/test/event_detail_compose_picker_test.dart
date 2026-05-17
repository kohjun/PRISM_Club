import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/event_detail/data/event_detail_dto.dart';
import 'package:mobile/features/event_detail/ui/widgets/compose_room_picker.dart';

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

Widget _hostScreen(VoidCallback onOpen) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextButton(
            onPressed: onOpen,
            child: const Text('open'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('shows both rooms with the default tile flagged "추천"',
      (tester) async {
    String? picked = 'NOT-YET';
    final rooms = [
      _room('dating-event-reviews', '소개팅/매칭 이벤트 후기'),
      _room('swap-style-talk-game', '환승연애식 오프라인 토크 게임'),
    ];

    await tester.pumpWidget(_hostScreen(() => () {}));
    // Manually open the sheet from the test using the BuildContext of a
    // shown widget — pull it from the TextButton's element.
    final BuildContext ctx = tester.element(find.text('open'));
    final future = showComposeRoomPicker(
      ctx,
      eligibleRooms: rooms,
      defaultSlug: 'swap-style-talk-game',
    );
    await tester.pumpAndSettle();

    expect(find.text('어느 방에 작성할까요?'), findsOneWidget);
    expect(find.text('소개팅/매칭 이벤트 후기'), findsOneWidget);
    expect(find.text('환승연애식 오프라인 토크 게임'), findsOneWidget);
    expect(find.text('추천'), findsOneWidget);

    await tester.tap(find.text('환승연애식 오프라인 토크 게임'));
    await tester.pumpAndSettle();
    picked = await future;
    expect(picked, 'swap-style-talk-game');
  });

  testWidgets('dismiss returns null', (tester) async {
    final rooms = [_room('dating-event-reviews', '소개팅/매칭 이벤트 후기')];
    await tester.pumpWidget(_hostScreen(() => () {}));
    final BuildContext ctx = tester.element(find.text('open'));
    final future = showComposeRoomPicker(
      ctx,
      eligibleRooms: rooms,
      defaultSlug: 'dating-event-reviews',
    );
    await tester.pumpAndSettle();

    // Tap outside the sheet to dismiss.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    final picked = await future;
    expect(picked, isNull);
  });
}
