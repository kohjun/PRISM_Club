import 'package:flutter/material.dart';

import '../app/design_tokens.dart';
import '../features/reference/data/reference_dto.dart';

/// Reference card. 38×38 kind-colored icon block + uppercase kind label
/// (overline) + title (1-2 line truncate).
class ReferenceCardWidget extends StatelessWidget {
  const ReferenceCardWidget({
    super.key,
    required this.reference,
    this.compact = false,
  });

  final ReferenceDto reference;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(reference.type);
    final iconSize = compact ? 34.0 : 38.0;
    final pad = compact ? 10.0 : PrismSpacing.md;

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: PrismColors.bg,
        borderRadius: BorderRadius.circular(PrismRadius.md),
        border: Border.all(color: PrismColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: meta.bg,
              borderRadius: BorderRadius.circular(PrismRadius.sm + 2),
            ),
            child: Icon(meta.icon, color: meta.fg, size: 18),
          ),
          const SizedBox(width: PrismSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _labelFor(reference.type) +
                      (reference.sourceName != null && reference.sourceName!.isNotEmpty
                          ? ' · ${reference.sourceName}'
                          : ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: meta.fg,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  reference.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    height: 1.35,
                    color: PrismColors.ink1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: PrismSpacing.sm),
          const Icon(Icons.chevron_right, color: PrismColors.ink4, size: 18),
        ],
      ),
    );
  }

  String _labelFor(String type) {
    switch (type) {
      case 'TV_SHOW':
        return '예능 프로그램';
      case 'YOUTUBE':
        return '유튜브';
      case 'GAME_RULE':
        return '게임 룰';
      case 'ARTICLE':
        return '아티클';
      case 'IDEA':
        return '아이디어';
      default:
        return type;
    }
  }

  _RefMeta _metaFor(String type) {
    switch (type) {
      case 'YOUTUBE':
        return const _RefMeta(
          icon: Icons.play_circle_outline,
          bg: PrismColors.warningBg,
          fg: PrismColors.warningFg,
        );
      case 'TV_SHOW':
        return const _RefMeta(
          icon: Icons.menu_book_outlined,
          bg: PrismColors.successBg,
          fg: PrismColors.successFg,
        );
      case 'GAME_RULE':
        return const _RefMeta(
          icon: Icons.list_alt_outlined,
          bg: PrismColors.infoBg,
          fg: PrismColors.infoFg,
        );
      case 'ARTICLE':
        return const _RefMeta(
          icon: Icons.format_quote_outlined,
          bg: PrismColors.pp50,
          fg: PrismColors.pp700,
        );
      case 'IDEA':
        return const _RefMeta(
          icon: Icons.auto_awesome_outlined,
          bg: Color(0xFFE0E7FF),
          fg: Color(0xFF3730A3),
        );
      default:
        return const _RefMeta(
          icon: Icons.link,
          bg: PrismColors.bgTint,
          fg: PrismColors.ink2,
        );
    }
  }
}

class _RefMeta {
  const _RefMeta({required this.icon, required this.bg, required this.fg});
  final IconData icon;
  final Color bg;
  final Color fg;
}
