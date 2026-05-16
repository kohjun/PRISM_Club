import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../features/post/data/post_dto.dart';
import 'event_card_widget.dart';
import 'reference_card_widget.dart';

class PostCardWidget extends StatelessWidget {
  const PostCardWidget({
    super.key,
    required this.post,
    this.onTap,
    this.onLikePressed,
  });

  final PostDto post;
  final VoidCallback? onTap;
  final VoidCallback? onLikePressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: PrismColors.soft,
                    child: Text(
                      post.author.nickname.isNotEmpty
                          ? post.author.nickname.characters.first
                          : '?',
                      style:
                          const TextStyle(color: PrismColors.primary, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(post.author.nickname,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const Spacer(),
                  Text(_relativeTime(post.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: PrismColors.muted)),
                ],
              ),
              const SizedBox(height: 10),
              Text(post.body),
              if (post.attachments.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final a in post.attachments) ...[
                  if (a.asEventCard != null)
                    EventCardWidget(card: a.asEventCard!, compact: true),
                  if (a.asReference != null)
                    ReferenceCardWidget(
                        reference: a.asReference!, compact: true),
                  const SizedBox(height: 6),
                ],
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  InkWell(
                    onTap: onLikePressed,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Icon(
                            post.likedByMe
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: post.likedByMe
                                ? PrismColors.primary
                                : PrismColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text('${post.likeCount}',
                              style: const TextStyle(
                                  fontSize: 12, color: PrismColors.muted)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.mode_comment_outlined,
                      size: 16, color: PrismColors.muted),
                  const SizedBox(width: 4),
                  Text('${post.replyCount}',
                      style: const TextStyle(
                          fontSize: 12, color: PrismColors.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
  }
}
