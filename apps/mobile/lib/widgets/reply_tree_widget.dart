import 'package:flutter/material.dart';

import '../app/design_tokens.dart';
import '../features/post/data/reply_dto.dart';
import 'prism_avatar.dart';

/// Reply tree (max depth 2). Top-level replies render at the screen edge;
/// nested replies indent and keep the `subdirectory_arrow_right` prefix so
/// the existing widget test keeps passing.
class ReplyTreeWidget extends StatelessWidget {
  const ReplyTreeWidget({
    super.key,
    required this.replies,
    required this.onReply,
    required this.onLike,
    this.replyTarget,
    this.onAuthorTap,
  });

  final List<ReplyDto> replies;
  final void Function(ReplyDto parent) onReply;
  final void Function(ReplyDto reply) onLike;
  final ReplyDto? replyTarget;
  final ValueChanged<String>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final topLevel = replies.where((r) => r.parentReplyId == null).toList();
    final childrenByParent = <String, List<ReplyDto>>{};
    for (final r in replies) {
      final parent = r.parentReplyId;
      if (parent != null) {
        childrenByParent.putIfAbsent(parent, () => []).add(r);
      }
    }

    if (topLevel.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: PrismSpacing.xl3),
        child: Center(
          child: Text(
            '아직 댓글이 없어요. 첫 댓글을 남겨 보세요.',
            style: TextStyle(color: PrismColors.ink3, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final parent in topLevel) ...[
          _ReplyTile(
            reply: parent,
            highlighted: replyTarget?.id == parent.id,
            onReply: () => onReply(parent),
            onLike: () => onLike(parent),
            onAuthorTap: onAuthorTap,
          ),
          for (final child in childrenByParent[parent.id] ?? const <ReplyDto>[])
            Padding(
              padding: const EdgeInsets.only(left: PrismSpacing.xl3),
              child: _ReplyTile(
                reply: child,
                isChild: true,
                onLike: () => onLike(child),
                onAuthorTap: onAuthorTap,
              ),
            ),
          const SizedBox(height: PrismSpacing.sm),
        ],
      ],
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({
    required this.reply,
    this.onReply,
    this.onLike,
    this.isChild = false,
    this.highlighted = false,
    this.onAuthorTap,
  });

  final ReplyDto reply;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final bool isChild;
  final bool highlighted;
  final ValueChanged<String>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.sm,
        vertical: PrismSpacing.md,
      ),
      decoration: BoxDecoration(
        color: highlighted ? PrismColors.pp50 : Colors.transparent,
        borderRadius: BorderRadius.circular(PrismRadius.sm),
        border: isChild
            ? const Border(left: BorderSide(color: PrismColors.line2, width: 2))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isChild) ...[
            const Icon(
              Icons.subdirectory_arrow_right,
              size: 14,
              color: PrismColors.ink4,
            ),
            const SizedBox(width: 4),
          ],
          PrismAvatar(name: reply.author.nickname, size: 32),
          const SizedBox(width: PrismSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (onAuthorTap != null)
                      InkWell(
                        onTap: () => onAuthorTap!(reply.author.id),
                        borderRadius: BorderRadius.circular(PrismRadius.xs),
                        child: Text(
                          reply.author.nickname,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: PrismColors.ink1,
                          ),
                        ),
                      )
                    else
                      Text(
                        reply.author.nickname,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: PrismColors.ink1,
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _relativeTime(reply.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: PrismColors.ink4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reply.body,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    letterSpacing: -0.2,
                    color: PrismColors.ink1,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    InkWell(
                      onTap: onLike,
                      borderRadius: BorderRadius.circular(PrismRadius.xs),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Icon(
                              reply.likedByMe
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 14,
                              color: reply.likedByMe
                                  ? PrismColors.danger
                                  : PrismColors.ink4,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${reply.likeCount}',
                              style: TextStyle(
                                fontSize: 11,
                                color: reply.likedByMe
                                    ? PrismColors.danger
                                    : PrismColors.ink4,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (onReply != null) ...[
                      const SizedBox(width: PrismSpacing.md),
                      TextButton(
                        onPressed: onReply,
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '답글',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return tile;
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
