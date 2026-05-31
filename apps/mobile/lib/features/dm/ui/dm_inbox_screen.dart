import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
import '../data/dm_dto.dart';
import '../data/dm_repository.dart';

/// P6.9 — `/dm`. Lists the viewer's scoped-DM channels (most recent
/// first). Tapping a channel opens the thread.
class DmInboxScreen extends ConsumerWidget {
  const DmInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(dmChannelsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('메시지')),
      body: channels.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '메시지함을 불러오지 못했어요.',
          onRetry: () => ref.invalidate(dmChannelsProvider),
        ),
        data: (list) => list.items.isEmpty
            ? const EmptyView(
                message: '아직 주고받은 메시지가 없어요.\n모집·검수 흐름에서 대화를 시작할 수 있어요.',
              )
            : RefreshIndicator(
                color: PrismColors.pp600,
                onRefresh: () async => ref.invalidate(dmChannelsProvider),
                child: ListView.separated(
                  itemCount: list.items.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    color: PrismColors.divider,
                    indent: PrismSpacing.xl,
                    endIndent: PrismSpacing.xl,
                  ),
                  itemBuilder: (_, i) => _ChannelTile(channel: list.items[i]),
                ),
              ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel});
  final DmChannelDto channel;

  @override
  Widget build(BuildContext context) {
    final name = channel.counterpart.nickname ?? '(알 수 없는 사용자)';
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';
    final scopeLabel = channel.scope == 'RECRUITMENT' ? '모집' : '검수';
    return ListTile(
      key: Key('dm-channel-${channel.id}'),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: PrismColors.pp50,
        child: Text(
          initial,
          style: const TextStyle(
            color: PrismColors.pp700,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: PrismColors.ink1,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _ScopeChip(label: scopeLabel),
        ],
      ),
      subtitle: Text(
        channel.isClosed ? '종료된 대화' : '대화 열기',
        style: const TextStyle(fontSize: 12, color: PrismColors.ink4),
      ),
      trailing: channel.unread
          ? const CircleAvatar(radius: 4, backgroundColor: PrismColors.pp700)
          : null,
      onTap: () => context.push(
        '/dm/${channel.id}?peer=${Uri.encodeComponent(name)}',
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: PrismColors.bgTint,
          borderRadius: BorderRadius.circular(PrismRadius.sm),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: PrismColors.ink3,
          ),
        ),
      );
}
