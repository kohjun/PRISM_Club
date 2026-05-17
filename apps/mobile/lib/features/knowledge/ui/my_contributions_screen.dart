import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_error.dart';
import '../../../widgets/contribution_card_widget.dart';
import '../../../widgets/state_views.dart';
import '../data/contribution_repository.dart';

class MyContributionsScreen extends ConsumerWidget {
  const MyContributionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myContributionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 제안'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/spaces'),
        ),
      ),
      body: mine.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '제안 목록을 불러오지 못했어요.',
          onRetry: () => ref.invalidate(myContributionsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(
              message: '아직 제출한 제안이 없어요.\nTopic Hub에서 "정보 개선 제안"을 눌러 보세요.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myContributionsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = items[i];
                return ContributionCardWidget(
                  contribution: c,
                  onTap: () => context.go(
                      '/categories/${c.categorySlug}'),
                  onAuthorTap: (uid) => context.go('/users/$uid'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
