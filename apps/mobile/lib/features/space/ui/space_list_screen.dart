import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../core/current_user.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/topic_block.dart';
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
              padding: const EdgeInsets.only(right: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: PrismColors.bgTint,
                    borderRadius: BorderRadius.circular(PrismRadius.pill),
                  ),
                  child: Text(
                    user.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PrismColors.ink2,
                    ),
                  ),
                ),
              ),
            ),
          Consumer(
            builder: (ctx, ref, _) {
              final count = ref.watch(unreadCountProvider).valueOrNull ?? 0;
              return Badge(
                isLabelVisible: count > 0,
                label: Text(count > 9 ? '9+' : '$count'),
                backgroundColor: PrismColors.danger,
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: '알림',
                  onPressed: () => context.go('/me/notifications'),
                ),
              );
            },
          ),
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
          color: PrismColors.pp600,
          onRefresh: () async {
            ref.invalidate(spaceListProvider);
            ref.invalidate(meProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(PrismSpacing.xl),
            children: [
              const _CuratorBanner(),
              const _OpsBanner(),
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: PrismSpacing.md),
                _SpaceCard(space: items[i]),
              ],
              const SizedBox(height: PrismSpacing.xl2),
              const _MyContributionsTile(),
            ],
          ),
        ),
      ),
    );
  }
}

class _CuratorBanner extends ConsumerWidget {
  const _CuratorBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final isCurator = me.valueOrNull?.isCurator ?? false;
    if (!isCurator) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: PrismSpacing.md),
      child: _PurpleBanner(
        icon: Icons.fact_check_outlined,
        title: '검수 큐로 가기',
        subtitle: '대기 중인 지식 기여 제안을 검토하세요.',
        onTap: () => context.go('/curate'),
      ),
    );
  }
}

class _OpsBanner extends ConsumerWidget {
  const _OpsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final isOps = me.valueOrNull?.isOps ?? false;
    if (!isOps) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: PrismSpacing.md),
      child: _PurpleBanner(
        icon: Icons.dashboard_outlined,
        title: '운영 대시보드',
        subtitle: '신고/기여/모집/신규 가입 현황을 한눈에 보세요.',
        onTap: () => context.go('/admin/ops'),
      ),
    );
  }
}

class _PurpleBanner extends StatelessWidget {
  const _PurpleBanner({
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
        borderRadius: BorderRadius.circular(PrismRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(PrismSpacing.lg),
          decoration: BoxDecoration(
            color: PrismColors.pp50,
            borderRadius: BorderRadius.circular(PrismRadius.md),
            border: Border.all(color: PrismColors.pp200),
          ),
          child: Row(
            children: [
              Icon(icon, color: PrismColors.pp700, size: 20),
              const SizedBox(width: PrismSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: PrismColors.pp900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PrismColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: PrismColors.pp700),
            ],
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
      child: InkWell(
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        onTap: () => context.go('/me/contributions'),
        child: Padding(
          padding: const EdgeInsets.all(PrismSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PrismColors.pp50,
                  borderRadius: BorderRadius.circular(PrismRadius.sm + 2),
                ),
                child: const Icon(
                  Icons.history_edu_outlined,
                  color: PrismColors.pp700,
                  size: 20,
                ),
              ),
              const SizedBox(width: PrismSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '내 제안',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: PrismColors.ink1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Topic Hub에 보낸 제안 상태를 확인하세요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: PrismColors.ink3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: PrismColors.ink4),
            ],
          ),
        ),
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
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        onTap: () {
          if (locked) {
            _showLockDialog(context);
            return;
          }
          context.go('/spaces/${space.slug}/categories');
        },
        child: Padding(
          padding: const EdgeInsets.all(PrismSpacing.lg),
          child: Row(
            children: [
              if (locked)
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: PrismColors.warningBg,
                    borderRadius: BorderRadius.circular(PrismRadius.md + 2),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: PrismColors.warningFg,
                    size: 24,
                  ),
                )
              else
                TopicBlock(label: space.name, size: 56),
              const SizedBox(width: PrismSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            space.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: PrismColors.ink1,
                            ),
                          ),
                        ),
                        if (locked) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.lock,
                            size: 14,
                            color: PrismColors.ink4,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitleFor(space, locked: locked),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PrismColors.ink3,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: PrismSpacing.sm),
              const Icon(Icons.chevron_right, color: PrismColors.ink4),
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
