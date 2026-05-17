import 'package:flutter/material.dart';

import '../app/theme.dart';

class RoleBadgeRow extends StatelessWidget {
  const RoleBadgeRow({super.key, required this.roles, this.compact = false});

  final List<String> roles;
  final bool compact;

  static const _meta = {
    'VERIFIED_PLANNER': _BadgeMeta(label: 'Verified Planner', color: PrismColors.primary),
    'CURATOR': _BadgeMeta(label: 'Curator', color: Color(0xFF0EA5A4)),
    'ADMIN': _BadgeMeta(label: 'Admin', color: Color(0xFFDC2626)),
  };

  @override
  Widget build(BuildContext context) {
    // MEMBER is the default; never rendered.
    final visible = roles.where((r) => _meta.containsKey(r)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: visible.map((r) {
        final m = _meta[r]!;
        return _Chip(label: m.label, color: m.color, compact: compact);
      }).toList(),
    );
  }
}

class _BadgeMeta {
  const _BadgeMeta({required this.label, required this.color});
  final String label;
  final Color color;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.compact});
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
