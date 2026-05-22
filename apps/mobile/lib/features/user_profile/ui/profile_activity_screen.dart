import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/post_card_widget.dart';
import '../../../widgets/state_views.dart';
import '../../post/data/post_dto.dart';
import '../data/user_profile_repository.dart';

/// P4.5 cursor-paginated profile activity. We accumulate page results in
/// local state because Riverpod's FutureProvider replay model would
/// otherwise refetch the whole list whenever cursor changed. A scroll
/// listener fires the next page when the user nears the bottom — same
/// pattern the room timeline uses.
class ProfileActivityScreen extends ConsumerStatefulWidget {
  const ProfileActivityScreen({
    super.key,
    required this.userId,
    this.title,
  });

  final String userId;
  final String? title;

  @override
  ConsumerState<ProfileActivityScreen> createState() =>
      _ProfileActivityScreenState();
}

class _ProfileActivityScreenState extends ConsumerState<ProfileActivityScreen> {
  final _controller = ScrollController();
  final _items = <PostDto>[];
  String? _cursor;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _loadFirst();
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadFirst() async {
    try {
      final page = await ref
          .read(userProfileRepositoryProvider)
          .getActivity(widget.userId);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
        _initialLoading = false;
        _error = null;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _done || _cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(userProfileRepositoryProvider)
          .getActivity(widget.userId, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
        _loadingMore = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('더 불러오지 못했어요: ${e.message}')),
      );
    }
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? '활동')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_initialLoading) return const LoadingView();
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _loadFirst);
    }
    if (_items.isEmpty) {
      return const EmptyView(message: '아직 활동이 없어요');
    }
    return RefreshIndicator(
      color: PrismColors.pp600,
      onRefresh: _loadFirst,
      child: ListView.separated(
        controller: _controller,
        padding: const EdgeInsets.fromLTRB(
          PrismSpacing.xl,
          PrismSpacing.md,
          PrismSpacing.xl,
          PrismSpacing.xl4,
        ),
        itemCount: _items.length + (_done ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(height: PrismSpacing.md),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: PrismSpacing.lg),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: PrismColors.pp600,
                  ),
                ),
              ),
            );
          }
          final p = _items[index];
          return PostCardWidget(
            post: p,
            onTap: () => context.go('/posts/${p.id}'),
            onAuthorTap: (uid) => context.go('/users/$uid'),
          );
        },
      ),
    );
  }
}
