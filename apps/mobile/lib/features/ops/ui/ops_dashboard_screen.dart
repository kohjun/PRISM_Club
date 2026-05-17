import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
import '../data/ops_dto.dart';
import '../data/ops_repository.dart';

class OpsDashboardScreen extends ConsumerWidget {
  const OpsDashboardScreen({super.key});

  Future<void> _refreshSignals(BuildContext context, WidgetRef ref) async {
    try {
      final result =
          await ref.read(opsRepositoryProvider).refreshSignals();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '시그널 새로고침 완료: ${result.hubsProcessed} hub / ${result.signalsWritten} signals',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('시그널 새로고침 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(opsSummaryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('운영 대시보드'),
        actions: [
          TextButton.icon(
            onPressed: () => _refreshSignals(context, ref),
            icon: const Icon(Icons.refresh),
            label: const Text('시그널 새로고침'),
          ),
        ],
      ),
      body: summary.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '대시보드를 불러오지 못했어요.',
          onRetry: () => ref.invalidate(opsSummaryProvider),
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(opsSummaryProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CardRow(s: s),
              const SizedBox(height: 24),
              _Section(title: '최근 가입 (30일)'),
              for (final u in s.recentUsers)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(u.nickname ?? u.id.substring(0, 8)),
                  subtitle: Text(u.createdAt.toIso8601String().substring(0, 10)),
                  onTap: () => context.go('/users/${u.id}'),
                ),
              if (s.recentUsers.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('- 없음 -',
                        style: TextStyle(color: PrismColors.muted))),
              const SizedBox(height: 8),
              _Section(title: '최근 방 (30일)'),
              for (final r in s.recentRooms)
                ListTile(
                  leading: const Icon(Icons.meeting_room_outlined),
                  title: Text(r.name),
                  subtitle: Text(r.slug),
                  onTap: () => context.go('/rooms/${r.slug}'),
                ),
              if (s.recentRooms.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('- 없음 -',
                        style: TextStyle(color: PrismColors.muted))),
              const SizedBox(height: 8),
              _Section(title: '최근 글 (30일)'),
              for (final p in s.recentPosts)
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: Text(p.bodyPreview,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(p.roomSlug),
                  onTap: () => context.go('/posts/${p.id}'),
                ),
              if (s.recentPosts.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('- 없음 -',
                        style: TextStyle(color: PrismColors.muted))),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.s});
  final OpsSummaryDto s;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _OpsCard(
          icon: Icons.fact_check_outlined,
          title: '대기 중인 기여',
          value: '${s.pendingContributions}',
          onTap: () => context.go('/curate'),
        ),
        _OpsCard(
          icon: Icons.report_outlined,
          title: '열린 신고',
          value: '${s.openReports}',
          onTap: () => context.go('/admin/reports'),
        ),
        _OpsCard(
          icon: Icons.work_outline,
          title: '모집 (열림/전체)',
          value: '${s.recruitmentOpen}/${s.recruitmentTotal}',
          onTap: () => context.go('/spaces'),
        ),
        _OpsCard(
          icon: Icons.person_add_outlined,
          title: '신규 가입자 (30일)',
          value: '${s.recentUserCount}',
        ),
      ],
    );
  }
}

class _OpsCard extends StatelessWidget {
  const _OpsCard({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: PrismColors.primary),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(
                        color: PrismColors.muted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 20)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      );
}
