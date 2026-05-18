import 'package:flutter/material.dart';

import '../app/design_tokens.dart';

/// Topic / Category "block" — the colored square used as a Topic Hub icon.
///
/// Visual is a layered offset shape:
///   • back square (pp200), shifted right + down 2px
///   • front square (pp100) with a 1-char monogram in pp700
///
/// The whole brand keeps a single hue (Club Purple) — the handoff allowed
/// 10-color variants, but we keep brand discipline by using one pair so
/// the topic strip reads as a coherent set.
class TopicBlock extends StatelessWidget {
  const TopicBlock({
    super.key,
    required this.label,
    this.size = 44,
    this.radius,
  });

  /// 1-character label (Korean uses first 어절 char). If the caller passes a
  /// longer string, we render only the first character.
  final String label;
  final double size;

  /// Override the front-block radius. Defaults to `size * 0.28` so the
  /// proportions stay consistent across sizes.
  final double? radius;

  String get _char {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return '#';
    return trimmed.characters.first;
  }

  @override
  Widget build(BuildContext context) {
    final r = radius ?? (size * 0.28);
    final monoSize = size * 0.5;

    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: PrismColors.pp200,
                borderRadius: BorderRadius.circular(r),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PrismColors.pp100,
                borderRadius: BorderRadius.circular(r),
              ),
              child: Text(
                _char,
                style: TextStyle(
                  color: PrismColors.pp700,
                  fontWeight: FontWeight.w800,
                  fontSize: monoSize,
                  letterSpacing: -0.4,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
