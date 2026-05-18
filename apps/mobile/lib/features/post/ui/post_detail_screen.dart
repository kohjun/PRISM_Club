import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../core/current_user.dart';
import '../../../widgets/event_card_widget.dart';
import '../../../widgets/prism_avatar.dart';
import '../../../widgets/reference_card_widget.dart';
import '../../../widgets/reply_tree_widget.dart';
import '../../../widgets/state_views.dart';
import '../../saves/data/saves_repository.dart';
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
            content: Text(res.liked ? '좋아요 (${res.likeCount})' : '좋아요 취소'),
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
                color: PrismColors.pp600,
                onRefresh: () async {
                  ref.invalidate(_postProvider(widget.postId));
                  ref.invalidate(repliesProvider(widget.postId));
                },
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (p.isRecruitment && p.recruitmentFields != null) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          PrismSpacing.xl,
                          PrismSpacing.lg,
                          PrismSpacing.xl,
                          0,
                        ),
                        child: RecruitmentPostCard(
                          fields: p.recruitmentFields!,
                          isAuthor: me?.id == p.author.id,
                          onSetStatus: (status) =>
                              _setRecruitmentStatus(p, status),
                        ),
                      ),
                    ],
                    _PostBody(post: p, onLike: () => _toggleLikePost(p)),
                    const _BandSeparator(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        PrismSpacing.xl,
                        PrismSpacing.lg,
                        PrismSpacing.xl,
                        PrismSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '답글 ${p.replyCount}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: PrismColors.ink2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PrismSpacing.lg,
                      ),
                      child: replies.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: PrismSpacing.xl2),
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
                          onAuthorTap: (uid) => context.go('/users/$uid'),
                        ),
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
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
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

class _BandSeparator extends StatelessWidget {
  const _BandSeparator();

  @override
  Widget build(BuildContext context) =>
      Container(height: 8, color: PrismColors.bgSoft);
}

class _PostBody extends ConsumerWidget {
  const _PostBody({required this.post, required this.onLike});
  final PostDto post;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saveKey = 'POST:${post.id}';
    final saved = ref.watch(saveStateProvider(saveKey)).valueOrNull ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.xl,
        PrismSpacing.lg,
        PrismSpacing.xl,
        PrismSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.go('/users/${post.author.id}'),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                PrismAvatar(name: post.author.nickname, size: 44),
                const SizedBox(width: PrismSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        post.author.nickname,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: PrismColors.ink1,
                        ),
                      ),
                      Text(
                        '${post.roomName} · ${_fullTime(post.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: PrismColors.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PrismSpacing.cardPad),
          Text(
            post.body,
            style: const TextStyle(
              fontSize: 16.5,
              height: 1.6,
              letterSpacing: -0.2,
              color: PrismColors.ink1,
            ),
          ),
          if (post.attachments.isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.cardPad),
            for (final a in post.attachments) ...[
              if (a.asEventCard != null)
                EventCardWidget(
                  card: a.asEventCard!,
                  onTap: () => context.go('/events/${a.asEventCard!.id}'),
                ),
              if (a.asReference != null)
                ReferenceCardWidget(reference: a.asReference!),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: PrismSpacing.cardPad),
          Container(
            padding: const EdgeInsets.only(top: PrismSpacing.md),
            decoration: const BoxDecoration(
              border:
                  Border(top: BorderSide(color: PrismColors.divider)),
            ),
            child: Row(
              children: [
                _StatItem(label: '좋아요', value: post.likeCount),
                const SizedBox(width: PrismSpacing.lg),
                _StatItem(label: '답글', value: post.replyCount),
              ],
            ),
          ),
          const SizedBox(height: PrismSpacing.md),
          Container(
            padding: const EdgeInsets.only(top: PrismSpacing.md),
            decoration: const BoxDecoration(
              border:
                  Border(top: BorderSide(color: PrismColors.divider)),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: onLike,
                  borderRadius: BorderRadius.circular(PrismRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PrismSpacing.sm,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          post.likedByMe
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 20,
                          color: post.likedByMe
                              ? PrismColors.danger
                              : PrismColors.ink4,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.likeCount}',
                          style: TextStyle(
                            color: post.likedByMe
                                ? PrismColors.danger
                                : PrismColors.ink3,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: PrismSpacing.lg),
                const Icon(
                  Icons.mode_comment_outlined,
                  size: 20,
                  color: PrismColors.ink4,
                ),
                const SizedBox(width: 6),
                Text(
                  '${post.replyCount}',
                  style: const TextStyle(
                    color: PrismColors.ink3,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    saved ? Icons.bookmark : Icons.bookmark_outline,
                    color: saved ? PrismColors.pp700 : PrismColors.ink4,
                    size: 20,
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
          ),
        ],
      ),
    );
  }

  String _fullTime(DateTime t) =>
      '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: PrismColors.ink1,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: PrismColors.ink4,
          ),
        ),
      ],
    );
  }
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
        color: PrismColors.bg,
        border: Border(top: BorderSide(color: PrismColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        PrismSpacing.md,
        PrismSpacing.sm,
        PrismSpacing.md,
        MediaQuery.of(context).viewInsets.bottom + PrismSpacing.sm,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyTarget != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PrismSpacing.sm,
                  vertical: 4,
                ),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: PrismColors.pp50,
                  borderRadius: BorderRadius.circular(PrismRadius.sm),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${replyTarget!.author.nickname}에게 답글',
                        style: const TextStyle(
                          fontSize: 12,
                          color: PrismColors.pp700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: onCancelReply,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: PrismColors.pp700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                    ),
                  ),
                ),
                const SizedBox(width: PrismSpacing.sm),
                FilledButton(
                  onPressed: sending ? null : onSubmit,
                  child: sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
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
