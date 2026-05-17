import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_error.dart';
import '../../../core/current_user.dart';
import '../../../widgets/event_card_widget.dart';
import '../../../widgets/reference_card_widget.dart';
import '../../../widgets/reply_tree_widget.dart';
import '../../../widgets/state_views.dart';
import '../../../features/saves/data/saves_repository.dart';
import '../data/post_dto.dart';
import '../data/post_repository.dart';
import '../data/reaction_repository.dart';
import '../data/reply_dto.dart';
import '../data/reply_repository.dart';
import 'widgets/recruitment_post_card.dart';

final _postProvider = FutureProvider.family<PostDto, String>((ref, postId) {
  return ref.read(postRepositoryProvider).getById(postId);
});

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _composer = TextEditingController();
  ReplyDto? _replyTarget;
  bool _sending = false;

  Future<void> _toggleLikePost(PostDto post) async {
    try {
      final res = await ref
          .read(reactionRepositoryProvider)
          .toggleLike('POST', post.id);
      ref.invalidate(_postProvider(post.id));
      ref.invalidate(timelineProvider(post.roomSlug));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 600),
            content:
                Text(res.liked ? '좋아요 (${res.likeCount})' : '좋아요 취소'),
          ),
        );
      }
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('좋아요 실패: ${e.message}')),
        );
      }
    }
  }

  Future<void> _toggleLikeReply(ReplyDto reply) async {
    try {
      await ref
          .read(reactionRepositoryProvider)
          .toggleLike('REPLY', reply.id);
      ref.invalidate(repliesProvider(widget.postId));
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('좋아요 실패: ${e.message}')),
        );
      }
    }
  }

  Future<void> _setRecruitmentStatus(PostDto post, String status) async {
    try {
      await ref
          .read(postRepositoryProvider)
          .setRecruitmentStatus(post.id, status);
      ref.invalidate(_postProvider(post.id));
      ref.invalidate(timelineProvider(post.roomSlug));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('모집 상태가 $status 로 바뀌었어요.')),
        );
      }
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('상태 변경 실패: ${e.message}')),
        );
      }
    }
  }

  Future<void> _submitReply() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(replyRepositoryProvider).create(
            widget.postId,
            body: text,
            parentReplyId: _replyTarget?.id,
          );
      _composer.clear();
      setState(() => _replyTarget = null);
      ref.invalidate(repliesProvider(widget.postId));
      ref.invalidate(_postProvider(widget.postId));
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 작성 실패: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(_postProvider(widget.postId));
    final replies = ref.watch(repliesProvider(widget.postId));
    final me = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글'),
        actions: [
          post.maybeWhen(
            data: (p) {
              if (me?.id != p.author.id) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '삭제',
                onPressed: () => _confirmDelete(context, p),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: post.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '게시글을 불러오지 못했어요.',
          onRetry: () => ref.invalidate(_postProvider(widget.postId)),
        ),
        data: (p) => Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(_postProvider(widget.postId));
                  ref.invalidate(repliesProvider(widget.postId));
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (p.isRecruitment && p.recruitmentFields != null) ...[
                      RecruitmentPostCard(
                        fields: p.recruitmentFields!,
                        isAuthor: me?.id == p.author.id,
                        onSetStatus: (status) =>
                            _setRecruitmentStatus(p, status),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _PostBody(post: p, onLike: () => _toggleLikePost(p)),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('댓글',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    replies.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: LoadingView(),
                      ),
                      error: (e, _) => ErrorView(
                        message: e is ApiError ? e.message : '댓글 로드 실패',
                        onRetry: () =>
                            ref.invalidate(repliesProvider(widget.postId)),
                      ),
                      data: (items) => ReplyTreeWidget(
                        replies: items,
                        replyTarget: _replyTarget,
                        onReply: (parent) =>
                            setState(() => _replyTarget = parent),
                        onLike: _toggleLikeReply,
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            _ReplyComposer(
              controller: _composer,
              sending: _sending,
              replyTarget: _replyTarget,
              onCancelReply: () => setState(() => _replyTarget = null),
              onSubmit: _submitReply,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, PostDto post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('이 게시글을 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(postRepositoryProvider).delete(post.id);
        ref.invalidate(timelineProvider(post.roomSlug));
        if (context.mounted) context.go('/rooms/${post.roomSlug}');
      } on ApiError catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: ${e.message}')),
          );
        }
      }
    }
  }
}

class _PostBody extends ConsumerWidget {
  const _PostBody({required this.post, required this.onLike});
  final PostDto post;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saveKey = 'POST:${post.id}';
    final saved = ref.watch(saveStateProvider(saveKey)).valueOrNull ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: PrismColors.soft,
              child: Text(
                post.author.nickname.isNotEmpty
                    ? post.author.nickname.characters.first
                    : '?',
                style: const TextStyle(color: PrismColors.primary),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.author.nickname,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '${post.roomName} · ${_fullTime(post.createdAt)}',
                  style: const TextStyle(
                      fontSize: 11, color: PrismColors.muted),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(post.body, style: Theme.of(context).textTheme.bodyLarge),
        if (post.attachments.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final a in post.attachments) ...[
            if (a.asEventCard != null)
              EventCardWidget(
                card: a.asEventCard!,
                onTap: () => context.go('/events/${a.asEventCard!.id}'),
              ),
            if (a.asReference != null)
              ReferenceCardWidget(reference: a.asReference!),
            const SizedBox(height: 6),
          ],
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            InkWell(
              onTap: onLike,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      post.likedByMe ? Icons.favorite : Icons.favorite_border,
                      color: post.likedByMe
                          ? PrismColors.primary
                          : PrismColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Text('${post.likeCount}',
                        style: const TextStyle(color: PrismColors.muted)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.mode_comment_outlined,
                color: PrismColors.muted),
            const SizedBox(width: 4),
            Text('${post.replyCount}',
                style: const TextStyle(color: PrismColors.muted)),
            const Spacer(),
            IconButton(
              icon: Icon(
                saved ? Icons.bookmark : Icons.bookmark_outline,
                color: saved ? PrismColors.primary : PrismColors.muted,
              ),
              tooltip: saved ? '저장 취소' : '저장',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => ref
                  .read(saveStateProvider(saveKey).notifier)
                  .toggle(),
            ),
          ],
        ),
      ],
    );
  }

  String _fullTime(DateTime t) =>
      '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _ReplyComposer extends StatelessWidget {
  const _ReplyComposer({
    required this.controller,
    required this.sending,
    required this.replyTarget,
    required this.onSubmit,
    required this.onCancelReply,
  });

  final TextEditingController controller;
  final bool sending;
  final ReplyDto? replyTarget;
  final VoidCallback onSubmit;
  final VoidCallback onCancelReply;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PrismColors.background,
        border: Border(top: BorderSide(color: PrismColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyTarget != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: PrismColors.soft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${replyTarget!.author.nickname}에게 답글',
                        style: const TextStyle(
                            fontSize: 12, color: PrismColors.primary),
                      ),
                    ),
                    InkWell(
                      onTap: onCancelReply,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close,
                            size: 14, color: PrismColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '댓글 쓰기...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: sending ? null : onSubmit,
                  child: sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('보내기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
