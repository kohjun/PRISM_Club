import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/post_card_widget.dart';
import '../../../widgets/prism_avatar.dart';
import '../../../widgets/role_badge.dart';
import '../../../widgets/state_views.dart';
import '../data/block_mute_repository.dart';
import '../data/reputation_repository.dart';
import '../data/user_follow_repository.dart';
import '../data/user_profile_dto.dart';
import '../data/user_profile_repository.dart';
import 'widgets/edit_profile_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(userProfileProvider(userId));
    return Scaffold(
      backgroundColor: PrismColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: bundle.when(
          loading: () => const Text('프로필'),
          error: (_, _) => const Text('프로필'),
          data: (b) => Text(b.user.nickname ?? '프로필'),
        ),
        actions: [
          bundle.maybeWhen(
            data: (b) => b.isSelf
                ? IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: '프로필 편집',
                    onPressed: () => EditProfileSheet.show(
                      context,
                      userId: userId,
                      initialProfile: b.profile,
                      initialNickname: b.user.nickname ?? '',
                      initialAvatarUrl: b.user.avatarUrl,
                    ),
                  )
                : _OtherUserMenu(userId: userId),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: bundle.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '프로필을 불러오지 못했어요.',
          onRetry: () => ref.invalidate(userProfileProvider(userId)),
        ),
        data: (b) => RefreshIndicator(
          color: PrismColors.pp600,
          onRefresh: () async => ref.invalidate(userProfileProvider(userId)),
          child: _ProfileBody(bundle: b, userId: userId),
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.bundle, required this.userId});
  final UserProfileBundleDto bundle;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _HeroBlock(bundle: bundle, userId: userId),
        _CountRow(counts: bundle.counts),
        Container(height: 6, color: PrismColors.bgSoft),
        if (bundle.recentPosts.isNotEmpty) ...[
          const _SectionHeader(title: '최근 글'),
          ...bundle.recentPosts.map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PrismSpacing.xl,
                vertical: 5,
              ),
              child: PostCardWidget(
                post: p,
                onTap: () => context.push('/posts/${p.id}'),
                onAuthorTap: (uid) => context.push('/users/$uid'),
              ),
            ),
          ),
          if (bundle.counts.postCount > bundle.recentPosts.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PrismSpacing.xl,
                PrismSpacing.sm,
                PrismSpacing.xl,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    final nick = bundle.user.nickname ?? '';
                    final encoded = Uri.encodeQueryComponent(nick);
                    context.push(
                      '/users/$userId/activity${nick.isNotEmpty ? '?nickname=$encoded' : ''}',
                    );
                  },
                  child: Text(
                    '전체 글 ${bundle.counts.postCount}개 보기',
                  ),
                ),
              ),
            ),
          const SizedBox(height: PrismSpacing.lg),
        ],
        if (bundle.userRooms.isNotEmpty) ...[
          const _SectionHeader(title: '만든 방'),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PrismSpacing.xl,
              vertical: 4,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: bundle.userRooms
                  .map(
                    (r) => Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push('/rooms/${r.slug}'),
                        borderRadius:
                            BorderRadius.circular(PrismRadius.pill),
                        child: Semantics(
                          button: true,
                          label: '방 ${r.name}',
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: 44,
                              minWidth: 44,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: PrismSpacing.cardPad,
                              vertical: 10,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: PrismColors.pp50,
                              borderRadius: BorderRadius.circular(
                                  PrismRadius.pill),
                              border: Border.all(color: PrismColors.pp100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.tag,
                                  size: 14,
                                  color: PrismColors.pp700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  r.name,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: PrismColors.pp700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: PrismSpacing.lg),
        ],
        if (bundle.approvedContributions.isNotEmpty) ...[
          const _SectionHeader(title: '승인된 기여'),
          ...bundle.approvedContributions.map(
            (c) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PrismSpacing.xl,
                vertical: 4,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(PrismRadius.md),
                  onTap: () => context.push(
                    '/categories/${c.categorySlug}'
                    '?returnTo=${Uri.encodeQueryComponent('/users/$userId')}',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: PrismColors.successBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: PrismColors.successFg,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: PrismSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                c.topicHubTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: PrismColors.ink1,
                                ),
                              ),
                              const Text(
                                '승인됨',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: PrismColors.successFg,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: PrismColors.ink4,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: PrismSpacing.lg),
        ],
        if (bundle.recentPosts.isEmpty &&
            bundle.userRooms.isEmpty &&
            bundle.approvedContributions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: PrismSpacing.xl3),
            child: EmptyView(message: '아직 공개된 활동이 없어요.'),
          ),
        const SizedBox(height: 60),
      ],
    );
  }
}

class _HeroBlock extends ConsumerWidget {
  const _HeroBlock({required this.bundle, required this.userId});
  final UserProfileBundleDto bundle;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nick = bundle.user.nickname ?? '?';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [PrismColors.pp50, PrismColors.bg],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.xl,
        PrismSpacing.xl3 + kToolbarHeight,
        PrismSpacing.xl,
        PrismSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PrismAvatar(name: nick, size: 84),
              const SizedBox(width: PrismSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nick,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                        color: PrismColors.ink1,
                      ),
                    ),
                    if (bundle.profile.region != null &&
                        bundle.profile.region!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        bundle.profile.region!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PrismColors.ink3,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!bundle.isSelf)
                _FollowButton(userId: userId, initial: bundle.isFollowing),
            ],
          ),
          if (bundle.roles.isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.md),
            RoleBadgeRow(roles: bundle.roles),
          ],
          // P2.2: contribution reputation. Hidden when the user has no
          // resolved contributions yet so a fresh profile doesn't show
          // a "0점" bar that adds noise.
          _ReputationLine(userId: userId),
          if (bundle.profile.bio != null &&
              bundle.profile.bio!.isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.md),
            Text(
              bundle.profile.bio!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                letterSpacing: -0.2,
                color: PrismColors.ink2,
              ),
            ),
          ],
          if (bundle.profile.interests.isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.md),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: bundle.profile.interests
                  .map(
                    (it) => Container(
                      height: 28,
                      padding:
                          const EdgeInsets.symmetric(horizontal: PrismSpacing.md),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: PrismColors.bgTint,
                        borderRadius: BorderRadius.circular(PrismRadius.pill),
                      ),
                      child: Text(
                        it,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: PrismColors.ink2,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _FollowButton extends ConsumerWidget {
  const _FollowButton({required this.userId, required this.initial});
  final String userId;
  final bool initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userFollowProvider(userId));
    final followed = state.valueOrNull?.followed ?? initial;
    return SizedBox(
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(PrismRadius.pill),
          onTap: state.isLoading
              ? null
              : () async {
                  await ref.read(userFollowProvider(userId).notifier).toggle();
                  ref.invalidate(userProfileProvider(userId));
                },
          child: Center(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: followed ? PrismColors.bgTint : PrismColors.pp600,
                borderRadius: BorderRadius.circular(PrismRadius.pill),
                border: followed ? Border.all(color: PrismColors.line2) : null,
              ),
              child: Text(
                followed ? '팔로잉' : '팔로우',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: followed ? PrismColors.ink2 : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.counts});
  final ProfileCountsDto counts;

  Widget _cell(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.4,
              color: PrismColors.ink1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: PrismColors.ink3,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.xl,
        vertical: PrismSpacing.cardPad,
      ),
      child: Row(
        children: [
          _cell('글', counts.postCount),
          _cell('방', counts.roomCount),
          _cell('팔로워', counts.followerCount),
          _cell('팔로잉', counts.followingCount),
        ],
      ),
    );
  }
}

class _ReputationLine extends ConsumerWidget {
  const _ReputationLine({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userReputationProvider(userId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (rep) {
        if (!rep.hasActivity) return const SizedBox.shrink();
        final score = rep.weightedScore;
        final scoreText = score == score.roundToDouble()
            ? score.toInt().toString()
            : score.toStringAsFixed(1);
        return Padding(
          padding: const EdgeInsets.only(top: PrismSpacing.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: PrismSpacing.md,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: PrismColors.pp50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium_outlined,
                  size: 18,
                  color: PrismColors.pp700,
                ),
                const SizedBox(width: 6),
                Text(
                  '기여 점수 $scoreText점',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PrismColors.pp700,
                  ),
                ),
                const Spacer(),
                Text(
                  '승인 ${rep.approvedCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PrismColors.muted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          PrismSpacing.xl,
          PrismSpacing.cardPad,
          PrismSpacing.xl,
          PrismSpacing.sm,
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: PrismColors.ink1,
          ),
        ),
      );
}

/// P6.2 action menu that appears on the OTHER user's profile (when
/// `bundle.isSelf == false`). Block + mute are the load-bearing
/// destructive actions; report routes to the existing moderation flow.
class _OtherUserMenu extends ConsumerWidget {
  const _OtherUserMenu({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_OtherUserAction>(
      icon: const Icon(Icons.more_vert),
      tooltip: '더보기',
      onSelected: (action) => _handle(context, ref, action),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _OtherUserAction.mute,
          child: ListTile(
            leading: Icon(Icons.volume_off_outlined),
            title: Text('음소거'),
            subtitle: Text('피드/알림에서만 숨김'),
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: _OtherUserAction.block,
          child: ListTile(
            leading: Icon(Icons.block, color: PrismColors.danger),
            title: Text('차단'),
            subtitle: Text('상호 노출 / 답글 / 멘션 차단'),
            dense: true,
          ),
        ),
      ],
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _OtherUserAction action,
  ) async {
    final repo = ref.read(blockMuteRepositoryProvider);
    try {
      if (action == _OtherUserAction.mute) {
        await repo.mute(userId);
        ref.invalidate(muteListProvider);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('음소거했어요')),
        );
      } else {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('차단하시겠어요?'),
            content: const Text(
              '차단하면 이 사용자의 글이 보이지 않고, '
              '서로 답글·멘션·팔로우를 할 수 없어요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: PrismColors.danger,
                ),
                child: const Text('차단'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await repo.block(userId);
        ref.invalidate(blockListProvider);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('차단했어요')),
        );
      }
    } on ApiError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리 실패: ${e.message}')),
      );
    }
  }
}

enum _OtherUserAction { mute, block }
