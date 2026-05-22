import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../core/observability/crashlytics_bootstrap.dart';
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

  /// Confirm-then-throw test exception. Used to verify the Crashlytics
  /// pipeline reaches the Firebase console (~5 minute delivery SLA).
  /// Surfaced only on the admin/curator/moderator-gated ops dashboard.
  Future<void> _throwTestCrash(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Crashlytics 테스트 예외'),
        content: Text(
          '앱이 즉시 종료됩니다. 다시 열면 보고가 Firebase 콘솔로 전송돼요.'
          '\n\n'
          'collection: ${CrashlyticsBootstrap.collectionEnabled ? "ON" : "OFF (debug 빌드)"}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('예외 발생'),
          ),
        ],
      ),
    );
    if (ok == true) {
      CrashlyticsBootstrap.throwTestException();
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
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('시그널 새로고침'),
            style: TextButton.styleFrom(
              foregroundColor: PrismColors.pp700,
              minimumSize: const Size(0, 44),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: summary.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '대시보드를 불러오지 못했어요.',
          onRetry: () => ref.invalidate(opsSummaryProvider),
        ),
        data: (s) => RefreshIndicator(
          color: PrismColors.pp600,
          onRefresh: () async => ref.invalidate(opsSummaryProvider),
          child: ListView(
            padding: const EdgeInsets.all(PrismSpacing.xl),
            children: [
              _CardRow(s: s),
              const SizedBox(height: PrismSpacing.xl2),
              const _Section(title: '최근 가입 (30일)'),
              if (s.recentUsers.isEmpty) const _EmptyLine(),
              for (final u in s.recentUsers)
                _OpsTile(
                  icon: Icons.person_outline,
                  title: u.nickname ?? u.id.substring(0, 8),
                  subtitle: u.createdAt.toIso8601String().substring(0, 10),
                  onTap: () => context.go('/users/${u.id}'),
                ),
              const SizedBox(height: PrismSpacing.md),
              const _Section(title: '최근 방 (30일)'),
              if (s.recentRooms.isEmpty) const _EmptyLine(),
              for (final r in s.recentRooms)
                _OpsTile(
                  icon: Icons.meeting_room_outlined,
                  title: r.name,
                  subtitle: r.slug,
                  onTap: () => context.go('/rooms/${r.slug}'),
                ),
              const SizedBox(height: PrismSpacing.md),
              const _Section(title: '최근 글 (30일)'),
              if (s.recentPosts.isEmpty) const _EmptyLine(),
              for (final p in s.recentPosts)
                _OpsTile(
                  icon: Icons.article_outlined,
                  title: p.bodyPreview,
                  subtitle: p.roomSlug,
                  onTap: () => context.go('/posts/${p.id}'),
                ),
              const SizedBox(height: PrismSpacing.xl2),
              const _Section(title: 'QA / 진단'),
              _OpsTile(
                icon: Icons.bug_report_outlined,
                title: 'Crashlytics 테스트 예외 발생',
                subtitle: CrashlyticsBootstrap.collectionEnabled
                    ? '확인 → 즉시 종료 → 재실행 시 Firebase 콘솔로 전송'
                    : 'collection OFF — debug 빌드에선 콘솔에 도달하지 않음',
                onTap: () => _throwTestCrash(context),
              ),
              const SizedBox(height: PrismSpacing.xl3),
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
      spacing: 10,
      runSpacing: 10,
      children: [
        _OpsCard(
          icon: Icons.fact_check_outlined,
          title: '대기 중인 기여',
          value: '${s.pendingContributions}',
          onTap: () => context.go('/curate'),
          tint: PrismColors.pp50,
          fg: PrismColors.pp700,
        ),
        _OpsCard(
          icon: Icons.report_outlined,
          title: '열린 신고',
          value: '${s.openReports}',
          onTap: () => context.go('/admin/reports'),
          tint: PrismColors.dangerBg,
          fg: PrismColors.dangerFg,
        ),
        _OpsCard(
          icon: Icons.work_outline,
          title: '모집 (열림/전체)',
          value: '${s.recruitmentOpen}/${s.recruitmentTotal}',
          onTap: () => context.go('/spaces'),
          tint: PrismColors.warningBg,
          fg: PrismColors.warningFg,
        ),
        _OpsCard(
          icon: Icons.person_add_outlined,
          title: '신규 가입자 (30일)',
          value: '${s.recentUserCount}',
          tint: PrismColors.successBg,
          fg: PrismColors.successFg,
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
    required this.tint,
    required this.fg,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String value;
  final Color tint;
  final Color fg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PrismRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(PrismSpacing.cardPad),
            decoration: BoxDecoration(
              color: PrismColors.bg,
              borderRadius: BorderRadius.circular(PrismRadius.lg),
              border: Border.all(color: PrismColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(PrismRadius.sm + 2),
                  ),
                  child: Icon(icon, color: fg, size: 18),
                ),
                const SizedBox(height: PrismSpacing.sm),
                Text(
                  title,
                  style: const TextStyle(
                    color: PrismColors.ink3,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.6,
                    color: PrismColors.ink1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
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
        padding: const EdgeInsets.fromLTRB(0, PrismSpacing.sm, 0, 6),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: PrismColors.ink2,
          ),
        ),
      );
}

class _OpsTile extends StatelessWidget {
  const _OpsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PrismRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 10,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PrismColors.bgTint,
                  borderRadius: BorderRadius.circular(PrismRadius.sm + 2),
                ),
                child: Icon(icon, color: PrismColors.ink2, size: 16),
              ),
              const SizedBox(width: PrismSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: PrismColors.ink1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: PrismColors.ink4,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: PrismColors.ink4, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          '- 없음 -',
          style: TextStyle(color: PrismColors.ink4, fontSize: 12),
        ),
      );
}
