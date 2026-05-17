import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../widgets/post_card_widget.dart';
import '../../../widgets/role_badge.dart';
import '../../../widgets/state_views.dart';
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
      appBar: AppBar(
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
                    ),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: bundle.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (b) => _ProfileBody(bundle: b, userId: userId),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _HeroBlock(bundle: bundle, userId: userId),
        const Divider(height: 1),
        _CountRow(counts: bundle.counts),
        const Divider(height: 1),
        if (bundle.recentPosts.isNotEmpty) ...[
          const _SectionHeader(title: '최근 글'),
          ...bundle.recentPosts.map((p) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: PostCardWidget(
                  post: p,
                  onTap: () => context.go('/posts/${p.id}'),
                ),
              )),
        ],
        if (bundle.userRooms.isNotEmpty) ...[
          const _SectionHeader(title: '만든 방'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: bundle.userRooms
                  .map((r) => ActionChip(
                        label: Text(r.name),
                        onPressed: () => context.go('/rooms/${r.slug}'),
                      ))
                  .toList(),
            ),
          ),
        ],
        if (bundle.approvedContributions.isNotEmpty) ...[
          const _SectionHeader(title: '승인된 기여'),
          ...bundle.approvedContributions.map((c) => ListTile(
                leading: const Icon(Icons.check_circle_outline,
                    color: PrismColors.primary),
                title: Text(c.topicHubTitle),
                subtitle: Text('승인됨'),
                onTap: () => context.go('/categories/${c.categorySlug}'),
              )),
        ],
        if (bundle.recentPosts.isEmpty &&
            bundle.userRooms.isEmpty &&
            bundle.approvedContributions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(nickname: nick, avatarUrl: bundle.user.avatarUrl, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nick,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            )),
                    if (bundle.user.nickname != null)
                      Text(
                        bundle.profile.region != null
                            ? '${bundle.profile.region}'
                            : '',
                        style: const TextStyle(
                            color: PrismColors.muted, fontSize: 13),
                      ),
                  ],
                ),
              ),
              if (!bundle.isSelf)
                _FollowButton(userId: userId, initial: bundle.isFollowing),
            ],
          ),
          const SizedBox(height: 10),
          if (bundle.roles.isNotEmpty)
            RoleBadgeRow(roles: bundle.roles),
          if (bundle.profile.bio != null && bundle.profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(bundle.profile.bio!,
                maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          if (bundle.profile.interests.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: bundle.profile.interests
                  .map((it) => Chip(
                        label: Text(it, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: PrismColors.soft,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.nickname, required this.avatarUrl, this.size = 40});
  final String nickname;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(avatarUrl!),
      );
    }
    final initial = nickname.isNotEmpty ? nickname.characters.first : '?';
    final colors = [
      const Color(0xFF7C3AED),
      const Color(0xFF0EA5A4),
      const Color(0xFFDC2626),
      const Color(0xFFD97706),
      const Color(0xFF2563EB),
    ];
    final colorIdx = initial.codeUnitAt(0) % colors.length;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: colors[colorIdx].withValues(alpha: 0.18),
      child: Text(
        initial,
        style: TextStyle(
          color: colors[colorIdx],
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
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
    return FilledButton.tonal(
      onPressed: state.isLoading
          ? null
          : () async {
              await ref.read(userFollowProvider(userId).notifier).toggle();
              // Invalidate profile so counts refresh
              ref.invalidate(userProfileProvider(userId));
            },
      child: Text(followed ? '팔로잉' : '팔로우'),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.counts});
  final ProfileCountsDto counts;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, int value) => Expanded(
          child: Column(
            children: [
              Text('$value',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      color: PrismColors.muted, fontSize: 12)),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          cell('글', counts.postCount),
          cell('방', counts.roomCount),
          cell('팔로워', counts.followerCount),
          cell('팔로잉', counts.followingCount),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}
