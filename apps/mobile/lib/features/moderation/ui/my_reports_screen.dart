import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
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
                        r.status == 'OPEN'
                            ? '처리 대기 중'
                            : '처리됨: ${r.resolution ?? '-'}',
                      ),
                      trailing: Text(
                        r.createdAt.toIso8601String().substring(0, 10),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
