import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../app/design_tokens.dart';

/// P6.1: renders a body string with `@nickname` tokens as tappable
/// purple links. Same character class the server-side parser uses
/// (Korean + Latin + digits + underscore, 2–20 chars) so the visual
/// stays in lockstep with what the API actually mentions.
///
/// Tap callback gets the nickname (caller resolves to user id via
/// `/users/search`).
class MentionText extends StatefulWidget {
  const MentionText({
    super.key,
    required this.body,
    required this.onMentionTap,
    this.maxLines,
    this.overflow,
    this.style,
  });

  final String body;
  final void Function(String nickname) onMentionTap;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextStyle? style;

  @override
  State<MentionText> createState() => _MentionTextState();
}

// Mirror of MentionService.MENTION_REGEX on the server side. Stays in
// sync manually — there's no shared regex layer.
final RegExp _mentionRegex =
    RegExp(r'@([가-힣a-zA-Z0-9_]{2,20})');

class _MentionTextState extends State<MentionText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild recognizers from scratch so a body edit (rare for posts,
    // common for replies in future) doesn't leak old ones.
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final base = widget.style ??
        const TextStyle(
          fontSize: 14.5,
          height: 1.55,
          letterSpacing: -0.2,
          color: PrismColors.ink1,
        );

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _mentionRegex.allMatches(widget.body)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.body.substring(cursor, match.start)));
      }
      final nickname = match.group(1) ?? '';
      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onMentionTap(nickname);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: '@$nickname',
          style: const TextStyle(
            color: PrismColors.pp600,
            fontWeight: FontWeight.w600,
          ),
          recognizer: recognizer,
        ),
      );
      cursor = match.end;
    }
    if (cursor < widget.body.length) {
      spans.add(TextSpan(text: widget.body.substring(cursor)));
    }

    // Text.rich keeps the body discoverable by `find.text` and
    // `find.textContaining` in widget tests, while still rendering the
    // styled mention spans + recognizers. RichText would break the
    // existing test surface.
    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }
}
