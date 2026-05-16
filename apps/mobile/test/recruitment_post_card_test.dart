import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/post/data/recruitment_fields_dto.dart';
import 'package:mobile/features/post/ui/widgets/recruitment_post_card.dart';

RecruitmentFieldsDto _fields({String status = 'OPEN'}) => RecruitmentFieldsDto(
      role: '진행 어시스턴트',
      schedule: '5/30 19:00–22:00',
      location: '홍대 스튜디오',
      compensation: '8만원 + 식대',
      capacity: 2,
      applicationMethod: 'DM @studio_lead',
      status: status,
    );

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('renders all structured fields + OPEN status chip', (tester) async {
    await tester.pumpWidget(_wrap(RecruitmentPostCard(
      fields: _fields(),
      isAuthor: false,
      onSetStatus: null,
    )));
    expect(find.text('진행 어시스턴트'), findsOneWidget);
    expect(find.text('5/30 19:00–22:00'), findsOneWidget);
    expect(find.text('홍대 스튜디오'), findsOneWidget);
    expect(find.text('8만원 + 식대'), findsOneWidget);
    expect(find.text('2명'), findsOneWidget);
    expect(find.text('DM @studio_lead'), findsOneWidget);
    expect(find.text('모집 중'), findsOneWidget);
  });

  testWidgets('CLOSED status renders the closed chip', (tester) async {
    await tester.pumpWidget(_wrap(RecruitmentPostCard(
      fields: _fields(status: 'CLOSED'),
      isAuthor: false,
      onSetStatus: null,
    )));
    expect(find.text('모집 마감'), findsOneWidget);
  });

  testWidgets('FILLED status renders the filled chip', (tester) async {
    await tester.pumpWidget(_wrap(RecruitmentPostCard(
      fields: _fields(status: 'FILLED'),
      isAuthor: false,
      onSetStatus: null,
    )));
    expect(find.text('충원 완료'), findsOneWidget);
  });

  testWidgets('non-author does not see toggle row', (tester) async {
    await tester.pumpWidget(_wrap(RecruitmentPostCard(
      fields: _fields(),
      isAuthor: false,
      onSetStatus: null,
    )));
    expect(find.text('모집 마감'), findsNothing); // only the status chip is OPEN here
    // The button labels would say "모집 마감" too — gate by Find type for the button.
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('author sees the toggle row and can fire onSetStatus',
      (tester) async {
    String? captured;
    await tester.pumpWidget(_wrap(RecruitmentPostCard(
      fields: _fields(),
      isAuthor: true,
      onSetStatus: (s) async {
        captured = s;
      },
    )));
    expect(find.byType(OutlinedButton), findsNWidgets(3));

    await tester.tap(find.widgetWithText(OutlinedButton, '모집 마감'));
    await tester.pump();
    expect(captured, 'CLOSED');

    await tester.tap(find.widgetWithText(OutlinedButton, '충원 완료'));
    await tester.pump();
    expect(captured, 'FILLED');
  });
}
