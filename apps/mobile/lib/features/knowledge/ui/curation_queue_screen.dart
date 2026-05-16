import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              children: _statuses
                  .map((s) => ChoiceChip(
                        label: Text(_label(s)),
                        selected: _status == s,
                        onSelected: (_) => setState(() => _status = s),
                      ))
                  .toList(),
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
                      onRefresh: () async => ref
                          .invalidate(adminContributionsProvider(_status)),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final c = items[i];
                          return ContributionCardWidget(
                            contribution: c,
                            onTap: () => context.go('/curate/${c.id}'),
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
