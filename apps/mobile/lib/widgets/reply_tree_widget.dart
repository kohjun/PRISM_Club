import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../features/post/data/reply_dto.dart';

/// Renders a flat reply list as a two-level tree, grouped by parent_reply_id.
class ReplyTreeWidget extends StatelessWidget {
  const ReplyTreeWidget({
    super.key,
    required this.replies,
    required this.onReply,
    required this.onLike,
    this.replyTarget,
    this.onAuthorTap,
  });

  /// Flat list from the server; client groups depth-1 + depth-2.
  final List<ReplyDto> replies;

  /// Called when user taps "답글" on a top-level reply (depth-2 composer mode).
  final void Function(ReplyDto parent) onReply;

  final void Function(ReplyDto reply) onLike;

  /// If set, this reply is the active "replying to" target (highlighted).
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
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('아직 댓글이 없어요. 첫 댓글을 남겨 보세요.',
              style: TextStyle(color: PrismColors.muted)),
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
              padding: const EdgeInsets.only(left: 32),
              child: _ReplyTile(
                reply: child,
                isChild: true,
                onLike: () => onLike(child),
                onAuthorTap: onAuthorTap,
              ),
            ),
          const SizedBox(height: 6),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? PrismColors.soft : null,
        border: Border(
          left: BorderSide(
            color: isChild ? PrismColors.border : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isChild) ...[
                const Icon(Icons.subdirectory_arrow_right,
                    size: 14, color: PrismColors.muted),
                const SizedBox(width: 4),
              ],
              onAuthorTap != null
                  ? InkWell(
                      onTap: () => onAuthorTap!(reply.author.id),
                      borderRadius: BorderRadius.circular(4),
                      child: Text(reply.author.nickname,
                          style: Theme.of(context).textTheme.bodyMedium),
                    )
                  : Text(reply.author.nickname,
                      style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(width: 6),
              Text(_relativeTime(reply.createdAt),
                  style:
                      const TextStyle(fontSize: 11, color: PrismColors.muted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(reply.body),
          const SizedBox(height: 4),
          Row(
            children: [
              InkWell(
                onTap: onLike,
                borderRadius: BorderRadius.circular(6),
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
                            ? PrismColors.primary
                            : PrismColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text('${reply.likeCount}',
                          style: const TextStyle(
                              fontSize: 11, color: PrismColors.muted)),
                    ],
                  ),
                ),
              ),
              if (onReply != null) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onReply,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('답글',
                      style: TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
        ],
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
