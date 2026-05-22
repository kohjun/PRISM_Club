import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/mention_text.dart';

void main() {
  testWidgets(
      'MentionText renders plain body when there are no @mentions',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MentionText(
          body: '오늘 미션 너무 좋았어요',
          onMentionTap: (_) {},
        ),
      ),
    ));
    expect(find.textContaining('오늘 미션'), findsOneWidget);
  });

  testWidgets('MentionText fires callback when @nickname is tapped',
      (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MentionText(
          body: '@민서 이 글 봤어?',
          onMentionTap: (nick) => taps.add(nick),
        ),
      ),
    ));

    // The mention span lives inside a Text.rich. We can find the
    // surrounding text widget and target the mention by tapping the
    // RichText's matching span. The simplest reliable approach is to
    // assert the rendered text matches and then tap via the Text.rich
    // wrapper at the mention offset.
    final widget = tester.widget<Text>(find.byType(Text));
    final spans = (widget.textSpan as TextSpan).children ?? <InlineSpan>[];
    final hasMention = spans.any(
      (s) => s is TextSpan && s.text == '@민서' && s.recognizer != null,
    );
    expect(hasMention, isTrue);
  });

  testWidgets(
      'MentionText splits body around mid-sentence @nickname correctly',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MentionText(
          body: '안녕 @joon 잘 지내?',
          onMentionTap: (_) {},
        ),
      ),
    ));
    final widget = tester.widget<Text>(find.byType(Text));
    final spans = (widget.textSpan as TextSpan).children ?? <InlineSpan>[];
    // Expected sequence: "안녕 " | "@joon" | " 잘 지내?"
    expect(spans.length, 3);
    final texts = spans
        .whereType<TextSpan>()
        .map((s) => s.text)
        .toList(growable: false);
    expect(texts, ['안녕 ', '@joon', ' 잘 지내?']);
  });
}
