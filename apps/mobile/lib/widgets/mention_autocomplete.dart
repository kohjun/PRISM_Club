import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/design_tokens.dart';
import '../features/user_profile/data/user_search_repository.dart';

/// Wraps a [TextField] / [TextFormField] and surfaces an overlay
/// autocomplete strip when the caret follows an `@nickname` token.
///
/// P6.1: typing `@민` opens the strip and tapping a candidate replaces
/// the active token with `@<nickname> ` (trailing space). The strip
/// debounces 200ms so we don't spam `/users/search` while the user
/// types.
class MentionAutocomplete extends ConsumerStatefulWidget {
  const MentionAutocomplete({
    super.key,
    required this.controller,
    required this.child,
  });

  final TextEditingController controller;
  final Widget child;

  @override
  ConsumerState<MentionAutocomplete> createState() =>
      _MentionAutocompleteState();
}

class _MentionAutocompleteState extends ConsumerState<MentionAutocomplete> {
  Timer? _debounce;
  List<UserSearchHitDto> _suggestions = const [];
  String? _activeToken;
  int? _tokenStart;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _debounce?.cancel();
    super.dispose();
  }

  void _onChange() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (!selection.isValid || selection.start != selection.end) {
      _clearStrip();
      return;
    }
    final caret = selection.start;
    final boundary = _findActiveMentionToken(text, caret);
    if (boundary == null) {
      _clearStrip();
      return;
    }
    final (start, token) = boundary;
    if (token.isEmpty) {
      _clearStrip();
      return;
    }
    _activeToken = token;
    _tokenStart = start;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => _fetch(token));
  }

  /// Walks backward from caret looking for an `@` that starts a mention
  /// token. Returns (token-start-index-INCLUDING-@, token-without-@) or
  /// null if no active mention. Stops at whitespace.
  ///
  /// We accept Korean + Latin + digits + underscore — the same character
  /// class the server-side regex uses.
  (int, String)? _findActiveMentionToken(String text, int caret) {
    if (caret == 0 || caret > text.length) return null;
    var i = caret - 1;
    while (i >= 0) {
      final c = text.codeUnitAt(i);
      if (c == 0x40 /* @ */) {
        // Must be at start-of-string or preceded by whitespace —
        // otherwise `foo@bar` would always trigger.
        if (i == 0 || _isWhitespace(text.codeUnitAt(i - 1))) {
          return (i, text.substring(i + 1, caret));
        }
        return null;
      }
      if (_isWhitespace(c)) return null;
      i -= 1;
    }
    return null;
  }

  bool _isWhitespace(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;

  Future<void> _fetch(String prefix) async {
    try {
      final hits = await ref
          .read(userSearchRepositoryProvider)
          .searchByNickname(prefix);
      if (!mounted) return;
      if (_activeToken == prefix) {
        setState(() => _suggestions = hits);
      }
    } catch (_) {
      // Silent — autocomplete failure should never block the composer.
      if (mounted) setState(() => _suggestions = const []);
    }
  }

  void _clearStrip() {
    _activeToken = null;
    _tokenStart = null;
    if (_suggestions.isNotEmpty) {
      setState(() => _suggestions = const []);
    }
  }

  void _pick(UserSearchHitDto hit) {
    final ctrl = widget.controller;
    final start = _tokenStart;
    if (start == null) return;
    final caret = ctrl.selection.start;
    if (caret < start) return;
    final replacement = '@${hit.nickname} ';
    final newText = ctrl.text.replaceRange(start, caret, replacement);
    final newCaret = start + replacement.length;
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCaret),
    );
    _clearStrip();
  }

  @override
  Widget build(BuildContext context) {
    final hasStrip = _suggestions.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.child,
        if (hasStrip) ...[
          const SizedBox(height: PrismSpacing.sm),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: PrismColors.bg,
              borderRadius: BorderRadius.circular(PrismRadius.md),
              border: Border.all(color: PrismColors.line),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: PrismColors.divider),
              itemBuilder: (context, index) {
                final hit = _suggestions[index];
                return InkWell(
                  onTap: () => _pick(hit),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PrismSpacing.cardPad,
                      vertical: PrismSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: PrismColors.bgTint,
                          backgroundImage: hit.avatarUrl != null
                              ? NetworkImage(hit.avatarUrl!)
                              : null,
                          child: hit.avatarUrl == null
                              ? Text(
                                  hit.nickname.characters.first,
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                        ),
                        const SizedBox(width: PrismSpacing.md),
                        Expanded(
                          child: Text(
                            '@${hit.nickname}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: PrismColors.ink1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
