import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../data/chain_dto.dart';
import '../data/chain_repository.dart';

/// P7.2 — person-centric chain timeline. Sibling to the existing
/// `block_revision_history_screen` (which is version-centric). Reads
/// the same revision history under the hood but renders one row per
/// actor with a role badge and the revision version they touched.
class BlockChainTimelineScreen extends ConsumerWidget {
  const BlockChainTimelineScreen({super.key, required this.blockId});
  final String blockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blockChainProvider(blockId));
    return Scaffold(
      appBar: AppBar(title: const Text('기여자 체인')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '체인을 불러오지 못했어요: $e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: PrismColors.muted),
            ),
          ),
        ),
        data: (chain) {
          if (chain.items.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: chain.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ChainTile(entry: chain.items[i]),
          );
        },
      ),
    );
  }
}

class _ChainTile extends StatelessWidget {
  const _ChainTile({required this.entry});
  final ChainEntryDto entry;

  @override
  Widget build(BuildContext context) {
    final roleTheme = _themeForRole(entry.roleInChain);
    return Container(
      padding: const EdgeInsets.all(PrismSpacing.lg),
      decoration: BoxDecoration(
        color: PrismColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PrismColors.border, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: PrismColors.bgSoft,
                child: Text(
                  (entry.nickname ?? '?').characters.firstOrNull ?? '?',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PrismColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.nickname ?? '(삭제된 사용자)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PrismColors.ink1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: roleTheme.bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  roleTheme.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: roleTheme.fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '버전 v${entry.revisionVersion} · ${_humanDate(entry.actedAt)}',
            style: const TextStyle(fontSize: 12, color: PrismColors.muted),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          '아직 이 블록에 남은 기여 기록이 없어요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: PrismColors.muted),
        ),
      ),
    );
  }
}

class _RoleTheme {
  const _RoleTheme({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;
}

_RoleTheme _themeForRole(String role) {
  switch (role) {
    case 'CONTRIBUTION':
      return const _RoleTheme(
        label: '기여',
        bg: PrismColors.successBg,
        fg: PrismColors.successFg,
      );
    case 'ADMIN':
      return const _RoleTheme(
        label: '관리자',
        bg: PrismColors.warningBg,
        fg: PrismColors.warningFg,
      );
    default:
      return const _RoleTheme(
        label: '초기 등록',
        bg: PrismColors.bgSoft,
        fg: PrismColors.muted,
      );
  }
}

String _humanDate(String iso) {
  // Fall back to the raw string if parsing fails so a malformed
  // server payload doesn't crash the screen.
  try {
    final d = DateTime.parse(iso).toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  } catch (_) {
    return iso;
  }
}
