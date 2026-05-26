import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../data/validation_dto.dart';
import '../../data/validation_repository.dart';

/// P7.2 — small chip on a knowledge block card. Renders the label
/// (`검증 부족` / `검증 진행 중` / `충분히 검증됨`) using the
/// existing reputation/source-tier badge styling, and on tap opens a
/// signals bottom sheet that breaks down WHY the label is what it is.
///
/// Self-hides on loading / error so a slow network doesn't park a
/// half-rendered chip on the card.
class ValidationBadge extends ConsumerWidget {
  const ValidationBadge({super.key, required this.blockId});
  final String blockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blockValidationProvider(blockId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (v) => _Chip(validation: v, blockId: blockId),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.validation, required this.blockId});
  final ValidationDto validation;
  final String blockId;

  @override
  Widget build(BuildContext context) {
    final theme = _labelTheme(validation.label);
    return InkWell(
      key: Key('validation-badge-$blockId'),
      borderRadius: BorderRadius.circular(999),
      onTap: () => showValidationSignalsSheet(
        context,
        blockId: blockId,
        validation: validation,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 11, color: theme.fg),
            const SizedBox(width: 4),
            Text(
              validation.label,
              style: TextStyle(
                fontSize: 11,
                color: theme.fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelTheme {
  const _LabelTheme({required this.bg, required this.fg});
  final Color bg;
  final Color fg;
}

_LabelTheme _labelTheme(String label) {
  switch (label) {
    case '충분히 검증됨':
      return const _LabelTheme(
        bg: PrismColors.successBg,
        fg: PrismColors.successFg,
      );
    case '검증 진행 중':
      return const _LabelTheme(
        bg: PrismColors.warningBg,
        fg: PrismColors.warningFg,
      );
    default:
      return const _LabelTheme(
        bg: PrismColors.bgSoft,
        fg: PrismColors.muted,
      );
  }
}

/// P7.2 signals breakdown sheet. Surfaces the same four signals the
/// server uses to compute the score so the user can map "왜 이 검증
/// 강도가 나왔는가" without leaving the Topic Hub screen. From here
/// they can drill into the chain timeline (sibling screen to the
/// existing block revision history).
Future<void> showValidationSignalsSheet(
  BuildContext context, {
  required String blockId,
  required ValidationDto validation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: false,
    backgroundColor: PrismColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) {
      final s = validation.signals;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: PrismColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Text(
                    '검증 강도 · ${validation.label}',
                    style: Theme.of(sheetCtx).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    '점수 ${validation.score.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: PrismColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '아래 네 가지 시그널을 합쳐서 산출했어요. '
                '값이 크면 더 많이 검증된 블록이에요.',
                style: TextStyle(
                  fontSize: 12,
                  color: PrismColors.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              _SignalRow(label: '개정 횟수', value: '${s.revisions}회'),
              _SignalRow(label: '승인된 기여', value: '${s.approvals}건'),
              _SignalRow(
                label: '평균 큐레이터 점수',
                value: s.avgReputation.toStringAsFixed(1),
              ),
              _SignalRow(
                label: '등록 후 경과',
                value: s.ageDays >= 30 ? '30일+' : '${s.ageDays}일',
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const Key('open-chain-timeline'),
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  context.push('/knowledge-blocks/$blockId/chain');
                },
                icon: const Icon(Icons.timeline, size: 16),
                label: const Text('기여자 체인 보기'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: PrismColors.ink2),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: PrismColors.ink1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
