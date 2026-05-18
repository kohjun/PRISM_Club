import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/contribution_card_widget.dart';
import '../../../widgets/state_views.dart';
import '../data/contribution_dto.dart';
import '../data/contribution_repository.dart';

const _statuses = [
  ContributionStatus.pending,
  ContributionStatus.approved,
  ContributionStatus.rejected,
  ContributionStatus.needsChanges,
];

class CurationQueueScreen extends ConsumerStatefulWidget {
  const CurationQueueScreen({super.key});

  @override
  ConsumerState<CurationQueueScreen> createState() => _CurationQueueScreenState();
}

class _CurationQueueScreenState extends ConsumerState<CurationQueueScreen> {
  String _status = ContributionStatus.pending;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(adminContributionsProvider(_status));
    return Scaffold(
      appBar: AppBar(
        title: const Text('지식 기여 검수'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/spaces'),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
              PrismSpacing.xl,
              PrismSpacing.sm,
              PrismSpacing.xl,
              PrismSpacing.sm,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: PrismColors.divider),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _statuses.length; i++) ...[
                    _StatusFilterChip(
                      label: _label(_statuses[i]),
                      selected: _status == _statuses[i],
                      onTap: () => setState(() => _status = _statuses[i]),
                    ),
                    if (i < _statuses.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: list.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: e is ApiError ? e.message : '검수 큐를 불러오지 못했어요.',
                onRetry: () =>
                    ref.invalidate(adminContributionsProvider(_status)),
              ),
              data: (items) => items.isEmpty
                  ? EmptyView(message: '${_label(_status)} 항목이 없어요.')
                  : RefreshIndicator(
                      color: PrismColors.pp600,
                      onRefresh: () async => ref
                          .invalidate(adminContributionsProvider(_status)),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(PrismSpacing.xl),
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: PrismSpacing.sm),
                        itemBuilder: (context, i) {
                          final c = items[i];
                          return ContributionCardWidget(
                            contribution: c,
                            onTap: () => context.go('/curate/${c.id}'),
                            onAuthorTap: (uid) =>
                                context.go('/users/$uid'),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label 필터',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PrismRadius.pill),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: PrismSpacing.cardPad,
              vertical: 8,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? PrismColors.ink1 : PrismColors.bgTint,
              borderRadius: BorderRadius.circular(PrismRadius.pill),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : PrismColors.ink2,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension _CurationQueueLabels on _CurationQueueScreenState {
  String _label(String s) {
    switch (s) {
      case ContributionStatus.pending:
        return '대기';
      case ContributionStatus.approved:
        return '승인됨';
      case ContributionStatus.rejected:
        return '거절됨';
      case ContributionStatus.needsChanges:
        return '보완 요청';
      case ContributionStatus.withdrawn:
        return '철회됨';
      default:
        return s;
    }
  }
}
