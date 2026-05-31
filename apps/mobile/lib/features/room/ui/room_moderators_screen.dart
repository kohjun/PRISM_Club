import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
import '../../user_profile/data/user_search_repository.dart';
import '../data/room_role_dto.dart';
import '../data/room_role_repository.dart';

/// P6.12 — owner-only room moderator management. Lists the current
/// room moderators with a remove action, and lets the owner add a
/// moderator by searching nicknames. The server enforces owner-only
/// (403) regardless; this screen is only routed to from the owner's
/// room view.
class RoomModeratorsScreen extends ConsumerStatefulWidget {
  const RoomModeratorsScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<RoomModeratorsScreen> createState() =>
      _RoomModeratorsScreenState();
}

class _RoomModeratorsScreenState extends ConsumerState<RoomModeratorsScreen> {
  final _searchCtrl = TextEditingController();
  List<UserSearchHitDto> _results = const [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    try {
      final hits =
          await ref.read(userSearchRepositoryProvider).searchByNickname(q);
      if (mounted) setState(() => _results = hits);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _grant(String userId) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(roomRoleRepositoryProvider).grant(widget.slug, userId);
      ref.invalidate(roomRolesProvider(widget.slug));
      if (mounted) {
        setState(() {
          _busy = false;
          _results = const [];
          _searchCtrl.clear();
        });
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _revoke(String userId) async {
    setState(() => _busy = true);
    try {
      await ref.read(roomRoleRepositoryProvider).revoke(widget.slug, userId);
      ref.invalidate(roomRolesProvider(widget.slug));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(roomRolesProvider(widget.slug));
    return Scaffold(
      appBar: AppBar(title: const Text('모더레이터 관리')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('moderator-search-field'),
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: '닉네임으로 멤버 검색',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _search,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!,
                  style: const TextStyle(color: PrismColors.dangerFg)),
            ),
          if (_results.isNotEmpty)
            ..._results.map(
              (u) => ListTile(
                key: Key('search-hit-${u.id}'),
                title: Text(u.nickname),
                trailing: TextButton(
                  onPressed: _busy ? null : () => _grant(u.id),
                  child: const Text('모더 지정'),
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('모더 목록을 불러오지 못했어요: $e',
                    style: const TextStyle(color: PrismColors.muted)),
              ),
              data: (roles) {
                final mods =
                    roles.where((r) => r.role == 'MODERATOR').toList();
                if (mods.isEmpty) {
                  return const EmptyView(
                    message: '아직 지정된 모더레이터가 없어요.\n믿을 만한 멤버를 모더로 지정해 보세요.',
                  );
                }
                return ListView.separated(
                  itemCount: mods.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _ModeratorTile(
                    role: mods[i],
                    busy: _busy,
                    onRevoke: () => _revoke(mods[i].userId),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeratorTile extends StatelessWidget {
  const _ModeratorTile({
    required this.role,
    required this.busy,
    required this.onRevoke,
  });
  final RoomRoleDto role;
  final bool busy;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('moderator-${role.userId}'),
      leading: const CircleAvatar(
        radius: 16,
        backgroundColor: PrismColors.pp50,
        child: Icon(Icons.shield_outlined, size: 16, color: PrismColors.pp700),
      ),
      title: Text(role.nickname ?? '(알 수 없는 사용자)'),
      subtitle: const Text('모더레이터'),
      trailing: TextButton(
        key: Key('revoke-${role.userId}'),
        onPressed: busy ? null : onRevoke,
        style: TextButton.styleFrom(foregroundColor: PrismColors.dangerFg),
        child: const Text('해제'),
      ),
    );
  }
}
