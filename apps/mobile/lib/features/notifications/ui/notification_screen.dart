import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
import '../data/notification_dto.dart';
import '../data/notification_repository.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(context, ref),
            child: const Text('모두 읽음'),
          ),
        ],
      ),
      body: notifs.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '알림을 불러오지 못했어요.',
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (list) => list.items.isEmpty
            ? const EmptyView(message: '새 알림이 없어요')
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(notificationsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) => _NotificationTile(
                    notif: list.items[index],
                    onTap: () => _onTap(context, list.items[index]),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
    } on ApiError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: ${e.message}')),
        );
      }
    }
  }

  void _onTap(BuildContext context, NotificationDto notif) {
    final type = notif.type;
    if (type == 'REPLY_ON_POST' ||
        type == 'NESTED_REPLY' ||
        type == 'NEW_POST_IN_FOLLOWED_ROOM' ||
        type == 'RECRUITMENT_STATUS_CHANGED') {
      final postId = notif.payload['postId'] as String?;
      if (postId != null) context.go('/posts/$postId');
    } else if (type == 'CONTRIBUTION_RESOLVED') {
      context.go('/me/contributions');
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notif, required this.onTap});
  final NotificationDto notif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notif.isRead;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isUnread ? PrismColors.soft.withAlpha(128) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                _iconFor(notif.type),
                size: 20,
                color: PrismColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titleFor(notif),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                  ),
                  if (_previewFor(notif).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _previewFor(notif),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: PrismColors.muted),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(notif.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: PrismColors.muted),
                  ),
                ],
              ),
            ),
            if (isUnread)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 4),
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: PrismColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'REPLY_ON_POST':
        return Icons.mode_comment_outlined;
      case 'NESTED_REPLY':
        return Icons.reply_outlined;
      case 'NEW_POST_IN_FOLLOWED_ROOM':
        return Icons.notifications_none_outlined;
      case 'RECRUITMENT_STATUS_CHANGED':
        return Icons.campaign_outlined;
      case 'CONTRIBUTION_RESOLVED':
        return Icons.fact_check_outlined;
      default:
        return Icons.circle_notifications_outlined;
    }
  }

  String _titleFor(NotificationDto notif) {
    final author = notif.payload['authorNickname'] as String? ?? '';
    final room = notif.payload['roomName'] as String? ?? '';
    switch (notif.type) {
      case 'REPLY_ON_POST':
        return '$author님이 내 글에 댓글을 남겼어요.';
      case 'NESTED_REPLY':
        return '$author님이 내 댓글에 답글을 남겼어요.';
      case 'NEW_POST_IN_FOLLOWED_ROOM':
        return '[$room] 팔로우 중인 방에 새 글이 올라왔어요.';
      case 'RECRUITMENT_STATUS_CHANGED':
        final status = notif.payload['status'] as String? ?? '';
        return '[$room] 모집 상태가 $status 로 변경됐어요.';
      case 'CONTRIBUTION_RESOLVED':
        final hub = notif.payload['topicHubTitle'] as String? ?? '';
        final decision = notif.payload['decision'] as String? ?? '';
        return '[$hub] 내 제안이 $decision 처리됐어요.';
      default:
        return '새 알림이 있어요.';
    }
  }

  String _previewFor(NotificationDto notif) {
    return notif.payload['bodyPreview'] as String? ?? '';
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}
