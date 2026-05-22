import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
import '../data/revision_dto.dart';
import '../data/revision_repository.dart';

class BlockRevisionHistoryScreen extends ConsumerWidget {
  const BlockRevisionHistoryScreen({super.key, required this.blockId});

  final String blockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blockRevisionsProvider(blockId));
    return Scaffold(
      appBar: AppBar(title: const Text('변경 이력')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '변경 이력을 불러오지 못했어요.',
          onRetry: () => ref.invalidate(blockRevisionsProvider(blockId)),
        ),
        data: (list) => list.items.isEmpty
            ? const EmptyView(message: '변경 이력이 없어요.')
            : RefreshIndicator(
                color: PrismColors.pp600,
                onRefresh: () async =>
                    ref.invalidate(blockRevisionsProvider(blockId)),
                child: ListView.separated(
                  padding: const EdgeInsets.all(PrismSpacing.xl),
                  itemCount: list.items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: PrismSpacing.md),
                  itemBuilder: (_, i) =>
                      _RevisionCard(revision: list.items[i]),
                ),
              ),
      ),
    );
  }
}

class _RevisionCard extends StatelessWidget {
  const _RevisionCard({required this.revision});
  final RevisionDto revision;

  String get _sourceLabel {
    switch (revision.source) {
      case 'SEED':
        return '초기 시드';
      case 'ADMIN':
        return '운영자 수정';
      case 'CONTRIBUTION':
      default:
        return '기여로 반영';
    }
  }

  Color get _sourceTint {
    switch (revision.source) {
      case 'SEED':
        return PrismColors.muted;
      case 'ADMIN':
        return PrismColors.warningFg;
      case 'CONTRIBUTION':
      default:
        return PrismColors.pp700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PrismSpacing.lg),
      decoration: BoxDecoration(
        color: PrismColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: const Border.fromBorderSide(PrismElevation.flatBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _sourceTint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'v${revision.version} · $_sourceLabel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _sourceTint,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(revision.changedAt),
                style: const TextStyle(
                  color: PrismColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: PrismSpacing.sm),
          if (revision.changedByNickname != null)
            Text(
              '${revision.changedByNickname}님',
              style: const TextStyle(
                fontSize: 13,
                color: PrismColors.ink2,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            const Text(
              '시드 데이터',
              style: TextStyle(
                fontSize: 13,
                color: PrismColors.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: PrismSpacing.md),
          Text(
            revision.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: PrismColors.ink1,
            ),
          ),
          const SizedBox(height: PrismSpacing.xs),
          Text(
            revision.body,
            style: const TextStyle(
              fontSize: 13,
              color: PrismColors.ink2,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime utc) {
    final local = utc.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
