import 'package:flutter/material.dart';

import '../app/design_tokens.dart';

/// Role badges. MEMBER is the implicit default and never renders. Every other
/// role gets a paired bg+fg chip with an icon prefix, per the handoff
/// "프로필 뱃지" table.
class RoleBadgeRow extends StatelessWidget {
  const RoleBadgeRow({super.key, required this.roles, this.compact = false});

  final List<String> roles;
  final bool compact;

  static const Map<String, _BadgeMeta> _meta = {
    'HOST': _BadgeMeta(
      label: '진행자',
      bg: PrismColors.warningBg,
      fg: PrismColors.warningFg,
      icon: Icons.auto_awesome,
    ),
    'VERIFIED_PLANNER': _BadgeMeta(
      label: '기획자',
      bg: PrismColors.pp100,
      fg: PrismColors.pp700,
      icon: Icons.tune,
    ),
    'CURATOR': _BadgeMeta(
      label: '큐레이터',
      bg: PrismColors.successBg,
      fg: PrismColors.successFg,
      icon: Icons.menu_book_outlined,
    ),
    'MODERATOR': _BadgeMeta(
      label: '모더레이터',
      bg: PrismColors.successBg,
      fg: PrismColors.successFg,
      icon: Icons.check_circle_outline,
    ),
    'ADMIN': _BadgeMeta(
      label: '운영',
      bg: PrismColors.ink1,
      fg: Colors.white,
      icon: Icons.settings,
    ),
    'VERIFIED': _BadgeMeta(
      label: '인증',
      bg: PrismColors.info,
      fg: Colors.white,
      icon: Icons.verified_outlined,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final visible = roles.where(_meta.containsKey).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: visible
          .map((r) => _Chip(meta: _meta[r]!, compact: compact))
          .toList(),
    );
  }
}

class _BadgeMeta {
  const _BadgeMeta({
    required this.label,
    required this.bg,
    required this.fg,
    required this.icon,
  });

  final String label;
  final Color bg;
  final Color fg;
  final IconData icon;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.meta, required this.compact});
  final _BadgeMeta meta;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 10.5 : 11.0;
    final iconSize = compact ? 11.0 : 12.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: meta.bg,
        borderRadius: BorderRadius.circular(PrismRadius.xs + 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: iconSize, color: meta.fg),
          const SizedBox(width: 4),
          Text(
            meta.label,
            style: TextStyle(
              color: meta.fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
