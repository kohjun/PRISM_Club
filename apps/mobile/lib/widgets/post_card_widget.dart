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
  });

  final PostDto post;
  final VoidCallback? onTap;
  final VoidCallback? onLikePressed;
  final ValueChanged<String>? onAuthorTap;

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
              if (post.attachments.isNotEmpty) ...[
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
        InkWell(
          onTap: onLikePressed,
          borderRadius: BorderRadius.circular(PrismRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Icon(
                  likedByMe ? Icons.favorite : Icons.favorite_border,
                  size: 18,
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
        const SizedBox(width: PrismSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.mode_comment_outlined,
                  size: 18, color: PrismColors.ink4),
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
      ],
    );
  }
}
