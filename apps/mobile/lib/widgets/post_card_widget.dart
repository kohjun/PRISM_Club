import 'package:flutter/material.dart';

import '../app/design_tokens.dart';
import '../features/post/data/post_dto.dart';
import 'event_card_widget.dart';
import 'media_image.dart';
import 'prism_avatar.dart';
import 'reference_card_widget.dart';

/// Post card. Header (avatar + name + handle + time + room) → body → optional
/// inline attachment (event / reference / image) → action row.
///
/// Wrapped in a flat-bordered `Card` so it stacks cleanly in Card-style
/// lists (Topic Hub, Home), and borderless when laid into a `ListView` with
/// dividers between (Room timeline — that screen pulls only the inner
/// Padded content via this widget's `Card` anyway; the Card border is light
/// enough that visual chrome stays subtle).
class PostCardWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
              Text(
                post.body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  letterSpacing: -0.2,
                  color: PrismColors.ink1,
                ),
              ),
              if (post.quotedPost != null) ...[
                const SizedBox(height: PrismSpacing.md),
                _QuotedBlock(quoted: post.quotedPost!),
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
                onLikePressed: onLikePressed,
              ),
            ],
          ),
        ),
      ),
    );
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
    this.onLikePressed,
  });

  final int likeCount;
  final int replyCount;
  final bool likedByMe;
  final VoidCallback? onLikePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          button: true,
          toggled: likedByMe,
          label: likedByMe ? '좋아요 취소' : '좋아요',
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
                  Icon(
                    likedByMe ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: likedByMe ? PrismColors.danger : PrismColors.ink4,
                  ),
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
      ],
    );
  }
}
