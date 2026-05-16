import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_error.dart';
import '../../../core/current_user.dart';
import '../../../widgets/state_views.dart';
import '../data/auth_repository.dart';
import '../data/dev_user_dto.dart';

final _devUsersProvider = FutureProvider<List<DevUserDto>>((ref) {
  return ref.read(authRepositoryProvider).listDevUsers();
});

class LoginPickerScreen extends ConsumerWidget {
  const LoginPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(_devUsersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('PRISM Club — 로그인 (개발용)')),
      body: users.when(
        loading: () => const LoadingView(message: '사용자 목록 로딩 중...'),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '사용자 목록을 불러오지 못했어요.',
          onRetry: () => ref.invalidate(_devUsersProvider),
        ),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _UserTile(user: items[i]),
        ),
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user});
  final DevUserDto user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(user.nickname.characters.first)),
        title: Text(user.nickname),
        subtitle: Text(user.id, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await ref
              .read(currentUserProvider.notifier)
              .setUser(CurrentUser(id: user.id, nickname: user.nickname));
          if (context.mounted) context.go('/spaces');
        },
      ),
    );
  }
}
