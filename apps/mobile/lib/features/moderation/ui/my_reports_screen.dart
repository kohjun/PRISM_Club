import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/status_pill.dart';
import '../data/moderation_repository.dart';

class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myReportsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('내 신고')),
      body: mine.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '신고 내역을 불러오지 못했어요.',
          onRetry: () => ref.invalidate(myReportsProvider),
        ),
        data: (list) => list.items.isEmpty
            ? const EmptyView(message: '아직 신고한 내역이 없어요.')
            : RefreshIndicator(
                color: PrismColors.pp600,
                onRefresh: () async => ref.invalidate(myReportsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(PrismSpacing.xl),
                  itemCount: list.items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: PrismSpacing.sm),
                  itemBuilder: (_, i) {
                    final r = list.items[i];
                    final isOpen = r.status == 'OPEN';
                    return Container(
                      padding: const EdgeInsets.all(PrismSpacing.cardPad),
                      decoration: BoxDecoration(
                        color: PrismColors.bg,
                        borderRadius: BorderRadius.circular(PrismRadius.md),
                        border: Border.all(color: PrismColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isOpen)
                                StatusPill.purple('대기')
                              else
                                StatusPill.success('처리됨'),
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
                              Text(
                                r.createdAt.toIso8601String().substring(0, 10),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: PrismColors.ink4,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: PrismSpacing.sm),
                          Text(
                            isOpen
                                ? '처리 대기 중'
                                : '결과: ${r.resolution ?? '-'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: PrismColors.ink3,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
