import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_error.dart';
import '../../../core/current_user.dart';
import '../../../widgets/state_views.dart';
import '../../auth/data/me_repository.dart';
import '../../notifications/data/notification_repository.dart';
import '../data/space_dto.dart';
import '../data/space_repository.dart';

class SpaceListScreen extends ConsumerWidget {
  const SpaceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final spaces = ref.watch(spaceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('커뮤니티 선택'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(label: Text(user.nickname)),
            ),
          Consumer(builder: (ctx, ref, _) {
            final count = ref.watch(unreadCountProvider).valueOrNull ?? 0;
            return Badge(
              isLabelVisible: count > 0,
              label: Text(count > 9 ? '9+' : '$count'),
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: '알림',
                onPressed: () => context.go('/me/notifications'),
              ),
            );
          }),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '검색',
            onPressed: () => context.go('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () async {
              await ref.read(currentUserProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: spaces.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '커뮤니티 목록을 불러오지 못했어요.',
          onRetry: () => ref.invalidate(spaceListProvider),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(spaceListProvider);
            ref.invalidate(meProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _CuratorBanner(),
              const _OpsBanner(),
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _SpaceCard(space: items[i]),
              ],
              const SizedBox(height: 24),
              const _MyContributionsTile(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders a "검수 큐로 가기" banner only when the signed-in user has
/// CURATOR or ADMIN. For regular members it collapses to nothing.
class _CuratorBanner extends ConsumerWidget {
  const _CuratorBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final isCurator = me.valueOrNull?.isCurator ?? false;
    if (!isCurator) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: PrismColors.soft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: PrismColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go('/curate'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.fact_check_outlined,
                    color: PrismColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('검수 큐로 가기',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: PrismColors.primary)),
                      const SizedBox(height: 2),
                      const Text(
                        '대기 중인 지식 기여 제안을 검토하세요.',
                        style: TextStyle(color: PrismColors.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: PrismColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Operational dashboard entry. Visible only for CURATOR/MODERATOR/ADMIN.
class _OpsBanner extends ConsumerWidget {
  const _OpsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final isOps = me.valueOrNull?.isOps ?? false;
    if (!isOps) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: PrismColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go('/admin/ops'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.dashboard_outlined,
                    color: PrismColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('운영 대시보드',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: PrismColors.primary)),
                      const SizedBox(height: 2),
                      const Text(
                        '신고/기여/모집/신규 가입 현황을 한눈에 보세요.',
                        style: TextStyle(color: PrismColors.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: PrismColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MyContributionsTile extends StatelessWidget {
  const _MyContributionsTile();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.history_edu_outlined,
            color: PrismColors.primary),
        title: const Text('내 제안'),
        subtitle: const Text('Topic Hub에 보낸 제안 상태를 확인하세요.',
            style: TextStyle(fontSize: 12, color: PrismColors.muted)),
        trailing: const Icon(Icons.chevron_right, color: PrismColors.muted),
        onTap: () => context.go('/me/contributions'),
      ),
    );
  }
}

class _SpaceCard extends ConsumerWidget {
  const _SpaceCard({required this.space});
  final SpaceDto space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).valueOrNull;
    final isPlannerSpace = space.isPlanner;
    final isVerifiedPlanner = me?.isPlanner ?? false;
    final locked = isPlannerSpace && !isVerifiedPlanner;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (locked) {
            _showLockDialog(context);
            return;
          }
          context.go('/spaces/${space.slug}/categories');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: locked ? PrismColors.border : PrismColors.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  locked ? Icons.lock_outline : Icons.groups_outlined,
                  color: locked ? PrismColors.muted : PrismColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          space.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (locked) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.lock,
                              size: 14, color: PrismColors.muted),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitleFor(space, locked: locked),
                      style: const TextStyle(color: PrismColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: PrismColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitleFor(SpaceDto space, {required bool locked}) {
    if (space.isPlanner) {
      return locked
          ? '스태프 모집, 운영 노트 · 인증 필요'
          : '스태프 모집, 운영 노트, 콘텐츠 기획 토론';
    }
    return '이벤트 후기와 콘텐츠 토론을 함께해요.';
  }

  void _showLockDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('인증된 기획자만 입장할 수 있어요'),
        content: const Text(
          '기획자 커뮤니티는 PRISM과 협업하는 검증된 기획자/스태프를 위한 공간입니다.\n\n'
          '이곳에서는 스태프 모집, 운영 노트, 콘텐츠 기획 토론이 진행됩니다.\n\n'
          '권한 신청은 운영자에게 문의해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
