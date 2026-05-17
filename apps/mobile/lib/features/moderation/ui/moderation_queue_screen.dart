import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/state_views.dart';
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
        error: (e, _) => ErrorView(message: e.toString()),
        data: (list) => list.items.isEmpty
            ? const EmptyView(message: '대기 중인 신고가 없습니다.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final r = list.items[i];
                  return Card(
                    child: ListTile(
                      title: Text('${r.targetType} · ${r.reason}'),
                      subtitle: Text(
                        '${r.reporterNickname ?? _short(r.reporterId, 6)} · '
                        '${_short(r.targetId, 8)}…',
                      ),
                      trailing: Text(r.status,
                          style: const TextStyle(fontSize: 12)),
                      onTap: () => context.go('/admin/reports/${r.id}'),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
