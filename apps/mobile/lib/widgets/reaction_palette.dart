import 'package:flutter/material.dart';

import '../app/design_tokens.dart';
import '../features/post/data/reaction_repository.dart';

/// P6.4 popup palette shown when the user long-presses the heart icon
/// on a post/reply. The six emojis are laid out on a single row so a
/// 360dp screen never overflows.
Future<String?> showReactionPalette(BuildContext context, {
  String? currentReaction,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final renderBox = context.findRenderObject() as RenderBox?;
  if (renderBox == null) return null;

  // Anchor relative to the long-pressed icon — show palette directly
  // above so the user's thumb doesn't cover it.
  final offset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
  final size = renderBox.size;
  final position = RelativeRect.fromLTRB(
    offset.dx,
    offset.dy - 60,
    overlay.size.width - offset.dx - size.width,
    overlay.size.height - offset.dy,
  );

  return showMenu<String>(
    context: context,
    position: position,
    color: Colors.transparent,
    elevation: 0,
    items: [
      PopupMenuItem<String>(
        enabled: false,
        padding: EdgeInsets.zero,
        child: Material(
          color: PrismColors.bg,
          elevation: 4,
          borderRadius: BorderRadius.circular(PrismRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PrismSpacing.sm,
              vertical: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in kReactionTypes)
                  _PaletteEmoji(
                    type: t,
                    selected: t == currentReaction,
                    onTap: () => Navigator.of(context).pop(t),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _PaletteEmoji extends StatelessWidget {
  const _PaletteEmoji({
    required this.type,
    required this.selected,
    required this.onTap,
  });
  final String type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: kReactionLabel[type] ?? type,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PrismRadius.pill),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          alignment: Alignment.center,
          decoration: selected
              ? BoxDecoration(
                  color: PrismColors.pp50,
                  borderRadius: BorderRadius.circular(PrismRadius.pill),
                )
              : null,
          child: Text(
            kReactionEmoji[type] ?? '?',
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
