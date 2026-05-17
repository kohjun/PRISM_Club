import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../widgets/event_card_widget.dart';
import '../../../widgets/post_card_widget.dart';
import '../../../widgets/state_views.dart';
import '../../event_card/data/event_card_dto.dart';
import '../../post/data/post_dto.dart';
import '../../room/data/room_summary_dto.dart';
import '../../saves/data/saved_item_dto.dart';
import '../data/home_dto.dart';
import '../data/home_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(homeBundleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('홈')),
      body: bundle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (b) => _HomeBody(bundle: b),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.bundle});
  final HomeBundleDto bundle;

  @override
  Widget build(BuildContext context) {
    final isEmpty = bundle.followedRoomUpdates.isEmpty &&
        bundle.recommendedRooms.isEmpty &&
        bundle.trendingPosts.isEmpty;

    return ListView(
      children: [
        if (bundle.followedRoomUpdates.isNotEmpty) ...[
          const _SectionHeader(title: '팔로우한 방 업데이트'),
          _HorizontalPostRow(posts: bundle.followedRoomUpdates),
        ],
        if (bundle.recommendedRooms.isNotEmpty) ...[
          const _SectionHeader(title: '추천 방'),
          _RoomChipRow(rooms: bundle.recommendedRooms),
        ],
        if (bundle.recommendedEvents.isNotEmpty) ...[
          const _SectionHeader(title: '추천 이벤트'),
          _HorizontalEventRow(events: bundle.recommendedEvents),
        ],
        if (bundle.trendingPosts.isNotEmpty) ...[
          const _SectionHeader(title: '인기 글'),
          ..._trendingTiles(context, bundle.trendingPosts),
        ],
        if (bundle.activeTopicHubs.isNotEmpty) ...[
          const _SectionHeader(title: '활성 토픽 허브'),
          ..._hubTiles(context, bundle.activeTopicHubs),
        ],
        if (bundle.savedRecently.isNotEmpty) ...[
          const _SectionHeader(title: '최근 저장'),
          ..._savedTiles(context, bundle.savedRecently),
        ],
        if (isEmpty)
          const EmptyView(message: '아직 표시할 콘텐츠가 없어요.\n방을 팔로우하고 활동을 시작해 보세요!'),
        const SizedBox(height: 80),
      ],
    );
  }

  List<Widget> _trendingTiles(BuildContext context, List<PostDto> posts) =>
      posts
          .map((p) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: PostCardWidget(
                  post: p,
                  onTap: () => context.go('/posts/${p.id}'),
                  onAuthorTap: (uid) => context.go('/users/$uid'),
                ),
              ))
          .toList();

  List<Widget> _hubTiles(
          BuildContext context, List<TopicHubSummaryDto> hubs) =>
      hubs
          .map((h) => ListTile(
                leading: const Icon(Icons.hub_outlined,
                    color: PrismColors.primary),
                title: Text(h.title),
                subtitle: Text('블록 ${h.blockCount}개'),
                onTap: () => context.go('/categories/${h.categorySlug}'),
              ))
          .toList();

  List<Widget> _savedTiles(
      BuildContext context, List<SavedItemDto> items) {
    final tiles = <Widget>[];
    for (final item in items) {
      String title;
      VoidCallback onTap;
      if (item.targetType == 'POST' && item.postTarget != null) {
        final body = item.postTarget!.body;
        title = body.length > 60 ? '${body.substring(0, 60)}…' : body;
        onTap = () => context.go('/posts/${item.targetId}');
      } else if (item.targetType == 'REFERENCE' &&
          item.referenceTarget != null) {
        title = item.referenceTarget!.title;
        onTap = () => context.go('/me/saves');
      } else if (item.targetType == 'EVENT_CARD' &&
          item.eventCardTarget != null) {
        title = item.eventCardTarget!.title;
        onTap = () => context.go('/events/${item.targetId}');
      } else {
        continue;
      }
      tiles.add(ListTile(
        leading:
            const Icon(Icons.bookmark, color: PrismColors.primary),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: onTap,
      ));
    }
    return tiles;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: PrismColors.text,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}

class _HorizontalPostRow extends StatelessWidget {
  const _HorizontalPostRow({required this.posts});
  final List<PostDto> posts;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 170,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: posts.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) => SizedBox(
            width: 260,
            child: PostCardWidget(
              post: posts[i],
              onTap: () => context.go('/posts/${posts[i].id}'),
              onAuthorTap: (uid) => context.go('/users/$uid'),
            ),
          ),
        ),
      );
}

class _RoomChipRow extends StatelessWidget {
  const _RoomChipRow({required this.rooms});
  final List<RoomSummaryDto> rooms;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: rooms.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ActionChip(
            label: Text(rooms[i].name),
            onPressed: () => context.go('/rooms/${rooms[i].slug}'),
          ),
        ),
      );
}

class _HorizontalEventRow extends StatelessWidget {
  const _HorizontalEventRow({required this.events});
  final List<EventCardDto> events;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 100,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: events.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) => SizedBox(
            width: 280,
            child: EventCardWidget(
              card: events[i],
              compact: true,
              onTap: () => context.go('/events/${events[i].id}'),
            ),
          ),
        ),
      );
}
