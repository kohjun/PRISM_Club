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

class _UserTile extends ConsumerStatefulWidget {
  const _UserTile({required this.user});
  final DevUserDto user;

  @override
  ConsumerState<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends ConsumerState<_UserTile> {
  bool _busy = false;

  /// M13: actually call POST /v1/auth/login, store the JWT, then navigate.
  Future<void> _loginAndGo(String path) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result =
          await ref.read(authRepositoryProvider).login(widget.user.id);
      await ref.read(currentUserProvider.notifier).setUser(
            CurrentUser(
              id: result.userId,
              nickname: result.nickname,
              accessToken: result.accessToken,
            ),
          );
      if (mounted) context.go(path);
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Card(
      child: ListTile(
        leading: _busy
            ? const SizedBox(
                width: 32,
                height: 32,
                child: Center(
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              )
            : CircleAvatar(child: Text(user.nickname.characters.first)),
        title: Text(user.nickname),
        subtitle: Text(user.id, style: const TextStyle(fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: '프로필 보기',
              onPressed: _busy ? null : () => _loginAndGo('/users/${user.id}'),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: _busy ? null : () => _loginAndGo('/home'),
      ),
    );
  }
}
