import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
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
          IconButton(
            tooltip: '알림 설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/me/notifications/settings'),
          ),
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
                color: PrismColors.pp600,
                onRefresh: () async => ref.invalidate(notificationsProvider),
                child: _GroupedNotificationList(
                  items: list.items,
                  onTap: (n) => _onTap(context, n),
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

/// Date-bucketed notification list. Groups items into 오늘 / 이번 주 /
/// 이전 by `createdAt`. This is a pure visual restructure — no new
/// filtering, no backend call, no item reordering beyond bucketing.
class _GroupedNotificationList extends StatelessWidget {
  const _GroupedNotificationList({
    required this.items,
    required this.onTap,
  });

  final List<NotificationDto> items;
  final ValueChanged<NotificationDto> onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));

    final today = <NotificationDto>[];
    final thisWeek = <NotificationDto>[];
    final earlier = <NotificationDto>[];

    for (final n in items) {
      if (!n.createdAt.isBefore(startOfToday)) {
        today.add(n);
      } else if (!n.createdAt.isBefore(startOfWeek)) {
        thisWeek.add(n);
      } else {
        earlier.add(n);
      }
    }

    final children = <Widget>[const SizedBox(height: PrismSpacing.sm)];

    void addGroup(String label, List<NotificationDto> rows) {
      if (rows.isEmpty) return;
      children.add(_GroupHeader(label: label));
      for (var i = 0; i < rows.length; i++) {
        children.add(_NotificationTile(notif: rows[i], onTap: () => onTap(rows[i])));
        if (i < rows.length - 1) {
          children.add(const Divider(
            height: 1,
            color: PrismColors.divider,
            indent: PrismSpacing.xl,
            endIndent: PrismSpacing.xl,
          ));
        }
      }
      children.add(const SizedBox(height: PrismSpacing.sm));
    }

    addGroup('오늘', today);
    addGroup('이번 주', thisWeek);
    addGroup('이전', earlier);
    children.add(const SizedBox(height: PrismSpacing.xl4));

    return ListView(
      padding: EdgeInsets.zero,
      children: children,
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.xl,
        PrismSpacing.md,
        PrismSpacing.xl,
        6,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: PrismColors.ink4,
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notif, required this.onTap});
  final NotificationDto notif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notif.isRead;
    final meta = _metaFor(notif.type);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: isUnread ? PrismColors.pp50 : null,
          padding: const EdgeInsets.symmetric(
            horizontal: PrismSpacing.xl,
            vertical: PrismSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isUnread)
                const Padding(
                  padding: EdgeInsets.only(top: 12, right: PrismSpacing.sm),
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: PrismColors.pp700,
                  ),
                ),
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: meta.bg,
                  shape: BoxShape.circle,
                ),
                child: Icon(meta.icon, size: 18, color: meta.fg),
              ),
              const SizedBox(width: PrismSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _titleFor(notif),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: PrismColors.ink1,
                        fontWeight:
                            isUnread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (_previewFor(notif).isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        _previewFor(notif),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PrismColors.ink3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _relativeTime(notif.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: PrismColors.ink4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({IconData icon, Color bg, Color fg}) _metaFor(String type) {
    switch (type) {
      case 'REPLY_ON_POST':
        return (
          icon: Icons.mode_comment_outlined,
          bg: PrismColors.infoBg,
          fg: PrismColors.infoFg,
        );
      case 'NESTED_REPLY':
        return (
          icon: Icons.reply_outlined,
          bg: PrismColors.infoBg,
          fg: PrismColors.infoFg,
        );
      case 'NEW_POST_IN_FOLLOWED_ROOM':
        return (
          icon: Icons.notifications_none_outlined,
          bg: PrismColors.pp100,
          fg: PrismColors.pp700,
        );
      case 'RECRUITMENT_STATUS_CHANGED':
        return (
          icon: Icons.campaign_outlined,
          bg: PrismColors.warningBg,
          fg: PrismColors.warningFg,
        );
      case 'CONTRIBUTION_RESOLVED':
        return (
          icon: Icons.fact_check_outlined,
          bg: PrismColors.successBg,
          fg: PrismColors.successFg,
        );
      default:
        return (
          icon: Icons.circle_notifications_outlined,
          bg: PrismColors.bgTint,
          fg: PrismColors.ink2,
        );
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
