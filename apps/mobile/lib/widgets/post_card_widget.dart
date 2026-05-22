import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/design_tokens.dart';
import '../features/post/data/boost_repository.dart';
import '../features/post/data/post_dto.dart';
import '../features/post/data/reaction_repository.dart';
import '../features/user_profile/data/user_search_repository.dart';
import 'event_card_widget.dart';
import 'media_image.dart';
import 'mention_text.dart';
import 'poll_widget.dart';
import 'prism_avatar.dart';
import 'reaction_palette.dart';
import 'reference_card_widget.dart';

/// Post card. Header (avatar + name + handle + time + room) → body → optional
/// inline attachment (event / reference / image) → action row.
///
/// Wrapped in a flat-bordered `Card` so it stacks cleanly in Card-style
/// lists (Topic Hub, Home), and borderless when laid into a `ListView` with
/// dividers between (Room timeline — that screen pulls only the inner
/// Padded content via this widget's `Card` anyway; the Card border is light
/// enough that visual chrome stays subtle).
class PostCardWidget extends ConsumerWidget {
  const PostCardWidget({
    super.key,
    required this.post,
    this.onTap,
    this.onLikePressed,
    this.onAuthorTap,
    this.compact = false,
  });

  final PostDto post;
  final VoidCallback? onTap;
  final VoidCallback? onLikePressed;
  final ValueChanged<String>? onAuthorTap;

  /// When true, the card omits the attachments block (event / reference
  /// preview cards + image previews). Used by fixed-height contexts
  /// like the Home horizontal "팔로우한 방 업데이트" strip where an
  /// inline `MediaImage(height: 180)` or attached event card would
  /// otherwise push the card past its 224dp container. Matches the
  /// convention on `EventCardWidget.compact` + `ReferenceCardWidget.compact`.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final header = _HeaderRow(post: post, onAuthorTap: onAuthorTap);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(PrismSpacing.cardPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: PrismSpacing.md),
              MentionText(
                body: post.body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                onMentionTap: (nick) =>
                    _navigateToMention(context, ref, nick),
              ),
              if (post.quotedPost != null) ...[
                const SizedBox(height: PrismSpacing.md),
                _QuotedBlock(quoted: post.quotedPost!),
              ],
              if (post.poll != null) ...[
                const SizedBox(height: PrismSpacing.md),
                PollWidget(
                  poll: post.poll!,
                  onVoted: (_) {
                    // The card itself is stateless; parent screens
                    // invalidate their providers on pull-to-refresh.
                  },
                ),
              ],
              if (!compact && post.attachments.isNotEmpty) ...[
                const SizedBox(height: PrismSpacing.md),
                for (final a in post.attachments) ...[
                  if (a.asEventCard != null)
                    EventCardWidget(card: a.asEventCard!, compact: true),
                  if (a.asReference != null)
                    ReferenceCardWidget(reference: a.asReference!, compact: true),
                  if (a.asImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(PrismRadius.md),
                      child: MediaImage(asset: a.asImage!, height: 180),
                    ),
                  const SizedBox(height: PrismSpacing.sm),
                ],
              ],
              const SizedBox(height: PrismSpacing.sm),
              _ActionRow(
                likeCount: post.likeCount,
                replyCount: post.replyCount,
                likedByMe: post.likedByMe,
                myReaction: post.myReaction,
                boostCount: post.boostCount,
                boostedByMe: post.boostedByMe,
                // F16: when the parent screen wires `onLikePressed`
                // (e.g. post_detail handles its own snackbar / refresh),
                // we forward to it. Otherwise the card itself toggles
                // HEART via the reaction repo so home / timeline /
                // saves / profile / search / event-detail all share the
                // same "tap heart" behaviour.
                onLikePressed:
                    onLikePressed ?? () => _onLikeTap(context, ref),
                onReactionPick: (type) => _onPick(context, ref, type),
                onBoostPressed: () => _onBoost(context, ref),
                onRepostMenu: () => _onRepostMenu(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Resolve a tapped @nickname to a user id via /users/search, then
  /// push to the profile. Silent failure if nothing matches — the
  /// nickname may have been deleted since the post was written.
  Future<void> _navigateToMention(
    BuildContext context,
    WidgetRef ref,
    String nickname,
  ) async {
    try {
      final hits = await ref
          .read(userSearchRepositoryProvider)
          .searchByNickname(nickname);
      final exact = hits.firstWhere(
        (h) => h.nickname == nickname,
        orElse: () => hits.isNotEmpty
            ? hits.first
            : const UserSearchHitDto(id: '', nickname: ''),
      );
      if (exact.id.isEmpty || !context.mounted) return;
      context.push('/users/${exact.id}');
    } catch (_) {
      // ignore — best-effort navigation
    }
  }

  /// P6.4: fires when the user picks an emoji from the palette. We
  /// toggle directly via the repo — the parent screen's `onLikePressed`
  /// is left intact for the legacy "tap heart" path (back-compat).
  /// State refresh after toggle is the parent's job via its existing
  /// provider invalidation.
  Future<void> _onPick(
    BuildContext context,
    WidgetRef ref,
    String type,
  ) async {
    try {
      await ref
          .read(reactionRepositoryProvider)
          .toggle('POST', post.id, reactionType: type);
    } catch (_) {
      // Silent — palette interaction shouldn't break the surface.
    }
  }

  /// P6.6: amplify-without-comment toggle. Same fire-and-forget pattern
  /// as the reaction pick — the parent screen's pull-to-refresh
  /// surfaces the new count.
  Future<void> _onBoost(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(boostRepositoryProvider).toggle(post.id);
    } catch (_) {
      // Silent.
    }
  }

  /// F16: default heart-tap when the parent screen doesn't wire its
  /// own `onLikePressed`. Toggles HEART via the reaction repo. The
  /// next provider read (pull-to-refresh, navigation back) surfaces
  /// the updated count.
  Future<void> _onLikeTap(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(reactionRepositoryProvider)
          .toggle('POST', post.id, reactionType: 'HEART');
    } catch (_) {
      // Silent.
    }
  }

  /// F17: long-press the repeat icon to open the retweet menu — choose
  /// between a comment-less boost (P6.6) or "인용하여 게시" which
  /// pushes the composer prefilled with this post (P4.2 quote path).
  Future<void> _onRepostMenu(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.repeat,
                color: post.boostedByMe ? PrismColors.pp700 : PrismColors.ink2,
              ),
              title: Text(post.boostedByMe ? '부스트 취소' : '부스트'),
              subtitle: const Text('코멘트 없이 팔로워에게 공유'),
              onTap: () => Navigator.of(ctx).pop('BOOST'),
            ),
            ListTile(
              leading: const Icon(Icons.format_quote, color: PrismColors.ink2),
              title: const Text('인용하여 게시'),
              subtitle: const Text('내 코멘트와 함께 새 글로 게시'),
              onTap: () => Navigator.of(ctx).pop('QUOTE'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'BOOST') {
      await _onBoost(context, ref);
    } else if (choice == 'QUOTE') {
      if (!context.mounted) return;
      final preview = post.body.length > 140
          ? '${post.body.substring(0, 140)}…'
          : post.body;
      final encodedPreview = Uri.encodeQueryComponent(preview);
      context.push(
        '/rooms/${post.roomSlug}/compose?quoted_post_id=${post.id}&quoted_preview=$encodedPreview',
      );
    }
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.post, this.onAuthorTap});
  final PostDto post;
  final ValueChanged<String>? onAuthorTap;

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final time = _relativeTime(post.createdAt);

    final inner = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PrismAvatar(name: post.author.nickname, size: 36),
        const SizedBox(width: PrismSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                post.author.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: PrismColors.ink1,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '$time · ${post.roomName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: PrismColors.ink3,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    if (onAuthorTap == null) return inner;
    return InkWell(
      onTap: () => onAuthorTap!(post.author.id),
      borderRadius: BorderRadius.circular(PrismRadius.sm),
      child: inner,
    );
  }
}

class _QuotedBlock extends StatelessWidget {
  const _QuotedBlock({required this.quoted});
  final QuotedPostRefDto quoted;

  @override
  Widget build(BuildContext context) {
    if (!quoted.available) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: PrismSpacing.cardPad,
          vertical: PrismSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: PrismColors.bgTint,
          borderRadius: BorderRadius.circular(PrismRadius.md),
        ),
        child: Row(
          children: const [
            Icon(Icons.block, size: 14, color: PrismColors.ink4),
            SizedBox(width: 6),
            Text(
              '삭제된 글입니다',
              style: TextStyle(
                fontSize: 12.5,
                color: PrismColors.ink3,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.cardPad,
        vertical: PrismSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: PrismColors.bgTint,
        borderRadius: BorderRadius.circular(PrismRadius.md),
        border: Border(
          left: BorderSide(color: PrismColors.pp400, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '@${quoted.authorNickname} · #${quoted.roomSlug}',
            style: const TextStyle(
              fontSize: 11.5,
              color: PrismColors.ink3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            quoted.bodyPreview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: PrismColors.ink2,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.likeCount,
    required this.replyCount,
    required this.likedByMe,
    this.myReaction,
    this.boostCount = 0,
    this.boostedByMe = false,
    this.onLikePressed,
    this.onReactionPick,
    this.onBoostPressed,
    this.onRepostMenu,
  });

  final int likeCount;
  final int replyCount;
  final bool likedByMe;
  final String? myReaction;
  final int boostCount;
  final bool boostedByMe;
  final VoidCallback? onLikePressed;
  final void Function(String type)? onReactionPick;
  final VoidCallback? onBoostPressed;
  final VoidCallback? onRepostMenu;

  @override
  Widget build(BuildContext context) {
    // P6.4: render the chosen emoji when set; fall back to the heart
    // icon for legacy "no reaction yet" + tap-only paths.
    final Widget reactionIcon = myReaction != null
        ? Text(
            kReactionEmoji[myReaction!] ?? '❤️',
            style: const TextStyle(fontSize: 18),
          )
        : Icon(
            likedByMe ? Icons.favorite : Icons.favorite_border,
            size: 20,
            color: likedByMe ? PrismColors.danger : PrismColors.ink4,
          );

    return Row(
      children: [
        Semantics(
          button: true,
          toggled: likedByMe,
          label: likedByMe ? '리액션 변경' : '리액션 추가',
          child: GestureDetector(
            onLongPress: onReactionPick == null
                ? null
                : () async {
                    final picked = await showReactionPalette(
                      context,
                      currentReaction: myReaction,
                    );
                    if (picked != null) onReactionPick!(picked);
                  },
            child: InkWell(
              onTap: onLikePressed,
              borderRadius: BorderRadius.circular(PrismRadius.sm),
              child: Container(
                constraints:
                    const BoxConstraints(minHeight: 44, minWidth: 44),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Row(
                  children: [
                    reactionIcon,
                    const SizedBox(width: 6),
                    Text(
                      '$likeCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: likedByMe ? PrismColors.danger : PrismColors.ink3,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: PrismSpacing.sm),
        Semantics(
          label: '답글 $replyCount개',
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.mode_comment_outlined,
                    size: 20, color: PrismColors.ink4),
                const SizedBox(width: 6),
                Text(
                  '$replyCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PrismColors.ink3,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: PrismSpacing.sm),
        Semantics(
          button: true,
          toggled: boostedByMe,
          label: boostedByMe ? '부스트 취소' : '부스트',
          child: InkWell(
            onTap: onBoostPressed,
            onLongPress: onRepostMenu,
            borderRadius: BorderRadius.circular(PrismRadius.sm),
            child: Container(
              constraints:
                  const BoxConstraints(minHeight: 44, minWidth: 44),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.repeat,
                    size: 20,
                    color:
                        boostedByMe ? PrismColors.pp700 : PrismColors.ink4,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$boostCount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          boostedByMe ? PrismColors.pp700 : PrismColors.ink3,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
