import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
import '../data/recruitment_dto.dart';
import '../data/recruitment_repository.dart';

class MyApplicationsScreen extends ConsumerWidget {
  const MyApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myApplicationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('내 지원 내역')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '지원 내역을 불러오지 못했어요.',
          onRetry: () => ref.invalidate(myApplicationsProvider),
        ),
        data: (list) => list.items.isEmpty
            ? const EmptyView(message: '아직 지원한 모집이 없어요.')
            : RefreshIndicator(
                color: PrismColors.pp600,
                onRefresh: () async =>
                    ref.invalidate(myApplicationsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(PrismSpacing.xl),
                  itemCount: list.items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: PrismSpacing.md),
                  itemBuilder: (_, i) => _Tile(entry: list.items[i]),
                ),
              ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.entry});
  final MyApplicationEntryDto entry;

  @override
  Widget build(BuildContext context) {
    final a = entry.application;
    return InkWell(
      onTap: () => GoRouter.of(context).go('/posts/${entry.postId}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(PrismSpacing.lg),
        decoration: BoxDecoration(
          color: PrismColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PrismColors.line, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.bodyPreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: PrismColors.ink1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(status: a.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '모집 ${entry.recruitmentStatus} · ${entry.roomSlug}',
              style: const TextStyle(
                fontSize: 12,
                color: PrismColors.muted,
              ),
            ),
            if (a.message != null && a.message!.isNotEmpty) ...[
              const SizedBox(height: PrismSpacing.sm),
              Text(
                '내 메시지: ${a.message}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: PrismColors.ink2,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
      'ACCEPTED' => ('수락', PrismColors.successFg, PrismColors.successBg),
      'REJECTED' => ('거절', PrismColors.dangerFg, PrismColors.dangerBg),
      'WITHDRAWN' => ('취소', PrismColors.muted, PrismColors.bgTint),
      _ => ('대기', PrismColors.warningFg, PrismColors.warningBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
