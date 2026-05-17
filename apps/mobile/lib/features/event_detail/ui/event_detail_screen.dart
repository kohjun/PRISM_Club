import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_error.dart';
import '../../../widgets/event_card_widget.dart';
import '../../../widgets/post_card_widget.dart';
import '../../../widgets/state_views.dart';
import '../../post/data/post_dto.dart';
import '../../saves/data/saves_repository.dart';
import '../data/event_detail_dto.dart';
import '../data/event_detail_repository.dart';
import 'widgets/compose_room_picker.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.cardId});
  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(eventDetailProvider(cardId));

    return Scaffold(
      appBar: AppBar(
        title: bundle.maybeWhen(
          data: (b) => Text(b.eventCard.title,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          orElse: () => const Text('이벤트'),
        ),
      ),
      body: bundle.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '이벤트 정보를 불러오지 못했어요.',
          onRetry: () => ref.invalidate(eventDetailProvider(cardId)),
        ),
        data: (b) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(eventDetailProvider(cardId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              EventCardWidget(card: b.eventCard),
              Consumer(builder: (ctx, ref, _) {
                final saveKey = 'EVENT_CARD:${b.eventCard.id}';
                final saved =
                    ref.watch(saveStateProvider(saveKey)).valueOrNull ??
                        false;
                return Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: Icon(saved
                        ? Icons.bookmark
                        : Icons.bookmark_outline),
                    label: Text(saved ? '저장됨' : '저장'),
                    onPressed: () => ref
                        .read(saveStateProvider(saveKey).notifier)
                        .toggle(),
                  ),
                );
              }),
              const SizedBox(height: 16),
              _RelatedRoomsSection(rooms: b.relatedRooms),
              const SizedBox(height: 20),
              _RelatedPostsSection(
                posts: b.relatedPosts,
                postCount: b.postCount,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: bundle.maybeWhen(
        data: (b) => _ComposeFab(bundle: b),
        orElse: () => null,
      ),
    );
  }
}

class _RelatedRoomsSection extends StatelessWidget {
  const _RelatedRoomsSection({required this.rooms});
  final List<RelatedRoomDto> rooms;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('관련 방 (${rooms.length})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final r in rooms) ...[
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PrismColors.soft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  r.origin == 'USER'
                      ? Icons.person_outline
                      : Icons.forum_outlined,
                  color: PrismColors.primary,
                  size: 20,
                ),
              ),
              title: Text(r.name),
              subtitle: Text(
                r.relation == 'PIN' ? '대표 자료로 고정' : '이 이벤트가 첨부된 글이 있는 방',
                style: const TextStyle(fontSize: 12),
              ),
              trailing:
                  const Icon(Icons.chevron_right, color: PrismColors.muted),
              onTap: () => context.go('/rooms/${r.slug}'),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _RelatedPostsSection extends StatelessWidget {
  const _RelatedPostsSection({required this.posts, required this.postCount});
  final List<PostDto> posts;
  final int postCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('관련 글 ($postCount)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (posts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: EmptyView(
              message: '아직 이 이벤트로 작성된 글이 없어요.\n첫 글을 남겨 보세요.',
            ),
          )
        else ...[
          for (final p in posts) ...[
            PostCardWidget(
              post: p,
              onTap: () => context.go('/posts/${p.id}'),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _ComposeFab extends StatelessWidget {
  const _ComposeFab({required this.bundle});
  final EventDetailBundleDto bundle;

  bool get _enabled =>
      bundle.relatedRooms.isNotEmpty ||
      (bundle.defaultComposeRoomSlug?.isNotEmpty ?? false);

  Future<void> _onPressed(BuildContext context) async {
    if (!_enabled) return;

    String? targetSlug;
    if (bundle.relatedRooms.length <= 1) {
      // 0 related rooms → use the fallback default; 1 → skip the picker.
      targetSlug = bundle.relatedRooms.isEmpty
          ? bundle.defaultComposeRoomSlug
          : bundle.relatedRooms.first.slug;
    } else {
      targetSlug = await showComposeRoomPicker(
        context,
        eligibleRooms: bundle.relatedRooms,
        defaultSlug: bundle.defaultComposeRoomSlug,
      );
    }

    if (targetSlug == null || targetSlug.isEmpty) return;
    if (!context.mounted) return;
    context.go(
      '/rooms/$targetSlug/compose?attach_event_card_id=${Uri.encodeQueryComponent(bundle.eventCard.id)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      icon: const Icon(Icons.edit),
      label: const Text('글 작성'),
      onPressed: _enabled ? () => _onPressed(context) : null,
      backgroundColor:
          _enabled ? PrismColors.primary : PrismColors.border,
      foregroundColor: _enabled ? Colors.white : PrismColors.muted,
    );
  }
}
