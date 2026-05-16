import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_error.dart';
import '../../../core/current_user.dart';
import '../../../widgets/state_views.dart';
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
          onRefresh: () async => ref.invalidate(spaceListProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _SpaceCard(space: items[i]),
          ),
        ),
      ),
    );
  }
}

class _SpaceCard extends StatelessWidget {
  const _SpaceCard({required this.space});
  final SpaceDto space;

  @override
  Widget build(BuildContext context) {
    final isPlanner = space.isPlanner;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isPlanner) {
            showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('준비 중'),
                content: const Text(
                  '기획자 커뮤니티는 인증 절차 마련 후 오픈할 예정입니다.\n'
                  '현재 마일스톤 1에서는 참가자 커뮤니티만 사용할 수 있어요.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('확인'),
                  ),
                ],
              ),
            );
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
                  color: isPlanner ? PrismColors.border : PrismColors.soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPlanner ? Icons.lock_outline : Icons.groups_outlined,
                  color: isPlanner ? PrismColors.muted : PrismColors.primary,
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
                        if (isPlanner) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.lock,
                              size: 14, color: PrismColors.muted),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPlanner
                          ? '인증된 기획자만 입장 가능 (준비 중)'
                          : '이벤트 후기와 콘텐츠 토론을 함께해요.',
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
}
