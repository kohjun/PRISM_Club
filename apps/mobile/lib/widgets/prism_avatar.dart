import 'package:flutter/material.dart';

import '../app/design_tokens.dart';

/// Avatar with a deterministic palette derived from the user's name.
///
/// The handoff uses initials only (no photo). Hash the name → pick 1 of 10
/// paired light-bg / dark-fg colors so the same user always gets the same
/// tile.
///
/// Sizes that match the handoff: 24 · 32 · 36 · 44 · 56 · 64 · 84.
class PrismAvatar extends StatelessWidget {
  const PrismAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.ring = false,
  });

  final String name;
  final double size;

  /// If true, paints a 2.5px white outer ring + 1px hairline (used in the
  /// EventDetail attendee stack so overlapping avatars stay legible).
  final bool ring;

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final pair = PrismAvatarPalette.pairFor(name);
    final fontSize = size * 0.42;

    final core = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pair.bg,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initial,
        style: TextStyle(
          color: pair.fg,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          letterSpacing: -0.3,
        ),
      ),
    );

    if (!ring) return core;

    return Container(
      decoration: const BoxDecoration(
        color: PrismColors.bg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: PrismColors.line, blurRadius: 0, spreadRadius: 1),
        ],
      ),
      padding: const EdgeInsets.all(2.5),
      child: core,
    );
  }
}
