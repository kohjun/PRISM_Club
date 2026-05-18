import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/post/ui/recruitment_composer_screen.dart';

Widget _wrap() => const ProviderScope(
      child: MaterialApp(
        home: RecruitmentComposerScreen(roomSlug: 'planner-recruitment'),
      ),
    );

// Find the AppBar submit "게시" button — restyled to FilledButton in the
// composer refresh.
Finder _submitButton() => find.widgetWithText(FilledButton, '게시');

void main() {
  setUp(() async {
    // The composer's ListView would lazily build off-screen fields on the
    // default 800×600 test surface — making them invisible to `find.byType`.
    // A tall surface keeps every TextField mounted at first pump.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> expandSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
  }

  testWidgets('submit disabled when fields are empty', (tester) async {
    await expandSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pump();

    final btn = tester.widget<FilledButton>(_submitButton());
    expect(btn.onPressed, isNull);
  });

  testWidgets('submit enabled when all required fields are valid',
      (tester) async {
    await expandSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pump();

    // Order matches the form: 역할, 일정, 장소, 보상, 인원, 지원 방법, then 본문.
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '진행 어시');
    await tester.enterText(textFields.at(1), '5/30 19:00');
    await tester.enterText(textFields.at(2), '홍대');
    await tester.enterText(textFields.at(3), '8만원');
    await tester.enterText(textFields.at(4), '2');
    await tester.enterText(textFields.at(5), 'DM @studio_lead');
    await tester.enterText(textFields.at(6), '모집합니다.');
    await tester.pump();

    final btn = tester.widget<FilledButton>(_submitButton());
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('submit remains disabled when capacity is "0" or non-numeric',
      (tester) async {
    await expandSurface(tester);
    await tester.pumpWidget(_wrap());
    await tester.pump();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '진행 어시');
    await tester.enterText(textFields.at(1), '5/30 19:00');
    await tester.enterText(textFields.at(2), '홍대');
    await tester.enterText(textFields.at(3), '8만원');
    await tester.enterText(textFields.at(5), 'DM');
    await tester.enterText(textFields.at(6), '모집');

    // capacity = 0 → invalid
    await tester.enterText(textFields.at(4), '0');
    await tester.pump();
    expect(tester.widget<FilledButton>(_submitButton()).onPressed, isNull);

    // capacity = abc → invalid
    await tester.enterText(textFields.at(4), 'abc');
    await tester.pump();
    expect(tester.widget<FilledButton>(_submitButton()).onPressed, isNull);
  });
}
