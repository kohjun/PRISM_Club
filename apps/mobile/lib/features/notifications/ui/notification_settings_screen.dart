import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
import '../data/notification_dto.dart';
import '../data/notification_prefs_repository.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  /// Optimistic local copy so toggles feel instant while the PATCH is
  /// in flight. Reverted on failure.
  NotificationPreferencesDto? _local;
  bool _pending = false;

  Future<void> _togglePref(
    String field,
    bool next,
    NotificationPreferencesDto Function(NotificationPreferencesDto)
        applyLocal,
  ) async {
    final prev = _local;
    if (prev == null) return;
    setState(() {
      _local = applyLocal(prev);
      _pending = true;
    });
    try {
      final updated = await ref
          .read(notificationPrefsRepositoryProvider)
          .patch({field: next});
      if (!mounted) return;
      setState(() {
        _local = updated;
        _pending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _local = prev;
        _pending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiError ? e.message : '알림 설정을 업데이트하지 못했어요.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(notificationPrefsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: prefsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '알림 설정을 불러오지 못했어요.',
          onRetry: () => ref.invalidate(notificationPrefsProvider),
        ),
        data: (server) {
          final p = _local ?? server;
          return ListView(
            padding: const EdgeInsets.symmetric(
              vertical: PrismSpacing.lg,
            ),
            children: [
              const _Section(title: '전송 채널'),
              _PrefTile(
                title: '푸시 알림',
                subtitle: '디바이스로 푸시 보내기 (꺼두면 아래 항목 모두 무음)',
                value: p.prefPushEnabled,
                enabled: !_pending,
                onChanged: (v) => _togglePref(
                  'pref_push_enabled',
                  v,
                  (s) => s.copyWith(prefPushEnabled: v),
                ),
              ),
              _PrefTile(
                title: '이메일 알림',
                subtitle: '향후 이메일 발송에 사용됨 (현재는 미적용)',
                value: p.prefEmailEnabled,
                enabled: !_pending,
                onChanged: (v) => _togglePref(
                  'pref_email_enabled',
                  v,
                  (s) => s.copyWith(prefEmailEnabled: v),
                ),
              ),
              const SizedBox(height: PrismSpacing.lg),
              const _Section(title: '받을 알림 종류'),
              _PrefTile(
                title: '내 글에 댓글이 달림',
                subtitle: 'REPLY_ON_POST',
                value: p.prefReplyOnPost,
                enabled: !_pending,
                onChanged: (v) => _togglePref(
                  'pref_reply_on_post',
                  v,
                  (s) => s.copyWith(prefReplyOnPost: v),
                ),
              ),
              _PrefTile(
                title: '내 댓글에 답글이 달림',
                subtitle: 'NESTED_REPLY',
                value: p.prefNestedReply,
                enabled: !_pending,
                onChanged: (v) => _togglePref(
                  'pref_nested_reply',
                  v,
                  (s) => s.copyWith(prefNestedReply: v),
                ),
              ),
              _PrefTile(
                title: '팔로우한 방의 새 글',
                subtitle: 'NEW_POST_IN_FOLLOWED_ROOM',
                value: p.prefNewPostInFollowedRoom,
                enabled: !_pending,
                onChanged: (v) => _togglePref(
                  'pref_new_post_in_followed_room',
                  v,
                  (s) => s.copyWith(prefNewPostInFollowedRoom: v),
                ),
              ),
              _PrefTile(
                title: '내 모집글 상태가 바뀜',
                subtitle: 'RECRUITMENT_STATUS_CHANGED',
                value: p.prefRecruitmentStatusChanged,
                enabled: !_pending,
                onChanged: (v) => _togglePref(
                  'pref_recruitment_status_changed',
                  v,
                  (s) => s.copyWith(prefRecruitmentStatusChanged: v),
                ),
              ),
              _PrefTile(
                title: '큐레이터가 내 제안을 검토함',
                subtitle: 'CONTRIBUTION_RESOLVED',
                value: p.prefContributionResolved,
                enabled: !_pending,
                onChanged: (v) => _togglePref(
                  'pref_contribution_resolved',
                  v,
                  (s) => s.copyWith(prefContributionResolved: v),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.xl,
        PrismSpacing.md,
        PrismSpacing.xl,
        PrismSpacing.sm,
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: PrismColors.muted,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: PrismColors.muted,
          fontSize: 12,
        ),
      ),
      value: value,
      activeThumbColor: PrismColors.pp600,
      onChanged: enabled ? onChanged : null,
    );
  }
}
