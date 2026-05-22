import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/status_pill.dart';
import '../data/moderation_repository.dart';

String _short(String s, int n) => s.length <= n ? s : s.substring(0, n);

class ModerationQueueScreen extends ConsumerWidget {
  const ModerationQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(moderationQueueProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('모더레이션 큐'),
      ),
      body: queue.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '모더레이션 큐를 불러오지 못했어요.',
          onRetry: () => ref.invalidate(moderationQueueProvider),
        ),
        data: (list) => list.items.isEmpty
            ? const EmptyView(message: '대기 중인 신고가 없습니다.')
            : RefreshIndicator(
                color: PrismColors.pp600,
                onRefresh: () async =>
                    ref.invalidate(moderationQueueProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(PrismSpacing.xl),
                  itemCount: list.items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: PrismSpacing.sm),
                  itemBuilder: (_, i) {
                    final r = list.items[i];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(PrismRadius.md),
                        onTap: () => context.push('/admin/reports/${r.id}'),
                        child: Container(
                          padding: const EdgeInsets.all(PrismSpacing.cardPad),
                          decoration: BoxDecoration(
                            color: PrismColors.bg,
                            borderRadius:
                                BorderRadius.circular(PrismRadius.md),
                            border: Border.all(color: PrismColors.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _ReportStatusPill(status: r.status),
                                  const SizedBox(width: PrismSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      '${r.targetType} · ${r.reason}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                        color: PrismColors.ink1,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                      color: PrismColors.ink4, size: 18),
                                ],
                              ),
                              const SizedBox(height: PrismSpacing.sm),
                              Text(
                                '${r.reporterNickname ?? _short(r.reporterId, 6)} · '
                                '대상 ${_short(r.targetId, 8)}…',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: PrismColors.ink4,
                                  fontFeatures: [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _ReportStatusPill extends StatelessWidget {
  const _ReportStatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    switch (status.toUpperCase()) {
      case 'OPEN':
      case 'PENDING':
        return StatusPill.purple('대기');
      case 'RESOLVED':
      case 'HIDDEN':
      case 'ACTIONED':
        return StatusPill.success('처리됨');
      case 'DISMISSED':
        return StatusPill.neutral('기각');
      case 'ESCALATED':
        return StatusPill.warning('상위 이관');
      default:
        return StatusPill.neutral(status);
    }
  }
}
