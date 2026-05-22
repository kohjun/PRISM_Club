import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/prism_avatar.dart';
import '../../../widgets/state_views.dart';
import '../data/block_mute_repository.dart';

/// P6.2: viewer-managed list of blocked users at `/me/blocks`.
/// `MuteListScreen` is its near-twin under `/me/mutes`.
class BlockListScreen extends ConsumerWidget {
  const BlockListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(blockListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('차단한 사용자')),
      body: blocks.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '차단 목록을 불러오지 못했어요.',
          onRetry: () => ref.invalidate(blockListProvider),
        ),
        data: (items) => items.isEmpty
            ? const EmptyView(message: '차단한 사용자가 없어요')
            : RefreshIndicator(
                color: PrismColors.pp600,
                onRefresh: () async => ref.invalidate(blockListProvider),
                child: ListView.separated(
                  itemCount: items.length,
                  padding: const EdgeInsets.symmetric(
                    vertical: PrismSpacing.md,
                  ),
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: PrismColors.divider),
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return ListTile(
                      onTap: () => context.push('/users/${e.userId}'),
                      leading: PrismAvatar(
                        name: e.nickname ?? '?',
                        size: 36,
                      ),
                      title: Text(e.nickname ?? '(닉네임 없음)'),
                      trailing: TextButton(
                        onPressed: () => _unblock(context, ref, e),
                        child: const Text('차단 해제'),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Future<void> _unblock(
    BuildContext context,
    WidgetRef ref,
    BlockMuteEntryDto entry,
  ) async {
    try {
      await ref.read(blockMuteRepositoryProvider).unblock(entry.userId);
      ref.invalidate(blockListProvider);
    } on ApiError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('차단 해제 실패: ${e.message}')),
      );
    }
  }
}

class MuteListScreen extends ConsumerWidget {
  const MuteListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutes = ref.watch(muteListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('음소거한 사용자')),
      body: mutes.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '음소거 목록을 불러오지 못했어요.',
          onRetry: () => ref.invalidate(muteListProvider),
        ),
        data: (items) => items.isEmpty
            ? const EmptyView(message: '음소거한 사용자가 없어요')
            : RefreshIndicator(
                color: PrismColors.pp600,
                onRefresh: () async => ref.invalidate(muteListProvider),
                child: ListView.separated(
                  itemCount: items.length,
                  padding: const EdgeInsets.symmetric(
                    vertical: PrismSpacing.md,
                  ),
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: PrismColors.divider),
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return ListTile(
                      onTap: () => context.push('/users/${e.userId}'),
                      leading: PrismAvatar(
                        name: e.nickname ?? '?',
                        size: 36,
                      ),
                      title: Text(e.nickname ?? '(닉네임 없음)'),
                      trailing: TextButton(
                        onPressed: () => _unmute(context, ref, e),
                        child: const Text('해제'),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Future<void> _unmute(
    BuildContext context,
    WidgetRef ref,
    BlockMuteEntryDto entry,
  ) async {
    try {
      await ref.read(blockMuteRepositoryProvider).unmute(entry.userId);
      ref.invalidate(muteListProvider);
    } on ApiError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('해제 실패: ${e.message}')),
      );
    }
  }
}
