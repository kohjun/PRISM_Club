import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/event_card/data/event_card_dto.dart';
import 'package:mobile/widgets/event_card_widget.dart';

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

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('without onTap, EventCardWidget is non-interactive', (tester) async {
    await tester.pumpWidget(_wrap(EventCardWidget(card: _card())));
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('with onTap, EventCardWidget is interactive and fires the callback',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(EventCardWidget(
      card: _card(),
      onTap: () => taps += 1,
    )));
    expect(find.byType(InkWell), findsOneWidget);

    await tester.tap(find.byType(EventCardWidget));
    await tester.pump();
    expect(taps, 1);
  });
}
