import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/event_card_widget.dart';
import '../../../widgets/post_card_widget.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/topic_block.dart';
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
      appBar: const _HomeAppBar(),
      body: bundle.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '홈을 불러오지 못했어요.',
          onRetry: () => ref.invalidate(homeBundleProvider),
        ),
        data: (b) => RefreshIndicator(
          color: PrismColors.pp600,
          onRefresh: () async => ref.invalidate(homeBundleProvider),
          child: _HomeBody(bundle: b),
        ),
      ),
    );
  }
}

class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HomeAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: PrismColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: PrismSpacing.xl,
      title: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: PrismColors.pp700,
              borderRadius: BorderRadius.circular(PrismRadius.sm - 1),
            ),
            alignment: Alignment.center,
            child: CustomPaint(
              size: const Size(14, 14),
              painter: _BrandTriangle(),
            ),
          ),
          const SizedBox(width: PrismSpacing.sm),
          const Text(
            'PRISM',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: PrismColors.ink1,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.auto_awesome_outlined, size: 22),
          color: PrismColors.ink2,
          onPressed: null,
          tooltip: '추천',
        ),
        IconButton(
          icon: const Icon(Icons.bookmark_outline, size: 22),
          color: PrismColors.ink2,
          onPressed: () => context.go('/me/saves'),
          tooltip: '저장',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _BrandTriangle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.18)
      ..lineTo(size.width * 0.86, size.height * 0.82)
      ..lineTo(size.width * 0.14, size.height * 0.82)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.bundle});
  final HomeBundleDto bundle;

  @override
  Widget build(BuildContext context) {
    final isEmpty = bundle.followedRoomUpdates.isEmpty &&
        bundle.recommendedRooms.isEmpty &&
        bundle.trendingPosts.isEmpty &&
        bundle.activeTopicHubs.isEmpty &&
        bundle.recommendedEvents.isEmpty &&
        bundle.savedRecently.isEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        if (bundle.activeTopicHubs.isNotEmpty) ...[
          const _OverlineHeader(text: '내가 들어간 TOPIC HUB'),
          _TopicHubStrip(hubs: bundle.activeTopicHubs),
          const _BandDivider(),
        ],
        if (bundle.followedRoomUpdates.isNotEmpty) ...[
          const _SectionHeader(title: '팔로우한 방 업데이트'),
          _HorizontalPostRow(posts: bundle.followedRoomUpdates),
          const SizedBox(height: PrismSpacing.lg),
        ],
        if (bundle.recommendedRooms.isNotEmpty) ...[
          const _SectionHeader(title: '추천 방'),
          _RoomChipRow(rooms: bundle.recommendedRooms),
          const SizedBox(height: PrismSpacing.lg),
        ],
        if (bundle.recommendedEvents.isNotEmpty) ...[
          const _SectionHeader(title: '추천 이벤트'),
          _HorizontalEventRow(events: bundle.recommendedEvents),
          const SizedBox(height: PrismSpacing.lg),
        ],
        if (bundle.trendingPosts.isNotEmpty) ...[
          const _SectionHeader(title: '인기 글'),
          ..._trendingTiles(context, bundle.trendingPosts),
          const SizedBox(height: PrismSpacing.lg),
        ],
        if (bundle.activeTopicHubs.isNotEmpty) ...[
          const _SectionHeader(title: '활성 토픽 허브'),
          ..._hubTiles(context, bundle.activeTopicHubs),
          const SizedBox(height: PrismSpacing.lg),
        ],
        if (bundle.savedRecently.isNotEmpty) ...[
          const _SectionHeader(title: '최근 저장'),
          ..._savedTiles(context, bundle.savedRecently),
          const SizedBox(height: PrismSpacing.lg),
        ],
        if (isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: PrismSpacing.xl4),
            child: EmptyView(
              message: '아직 표시할 콘텐츠가 없어요.\n방을 팔로우하고 활동을 시작해 보세요!',
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  List<Widget> _trendingTiles(BuildContext context, List<PostDto> posts) =>
      posts
          .map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PrismSpacing.xl,
                vertical: 5,
              ),
              child: PostCardWidget(
                post: p,
                onTap: () => context.go('/posts/${p.id}'),
                onAuthorTap: (uid) => context.go('/users/$uid'),
              ),
            ),
          )
          .toList();

  List<Widget> _hubTiles(BuildContext context, List<TopicHubSummaryDto> hubs) =>
      hubs
          .map(
            (h) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PrismSpacing.xl,
                vertical: 4,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(PrismRadius.md),
                  onTap: () => context.go('/categories/${h.categorySlug}'),
                  child: Padding(
                    padding: const EdgeInsets.all(PrismSpacing.md),
                    child: Row(
                      children: [
                        TopicBlock(label: h.title, size: 40),
                        const SizedBox(width: PrismSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '# ${h.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: PrismColors.ink1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '블록 ${h.blockCount}개',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: PrismColors.ink4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: PrismColors.ink4,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList();

  List<Widget> _savedTiles(BuildContext context, List<SavedItemDto> items) {
    final tiles = <Widget>[];
    for (final item in items) {
      String title;
      IconData icon;
      VoidCallback onTap;
      if (item.targetType == 'POST' && item.postTarget != null) {
        final body = item.postTarget!.body;
        title = body.length > 60 ? '${body.substring(0, 60)}…' : body;
        icon = Icons.chat_bubble_outline;
        onTap = () => context.go('/posts/${item.targetId}');
      } else if (item.targetType == 'REFERENCE' &&
          item.referenceTarget != null) {
        title = item.referenceTarget!.title;
        icon = Icons.link;
        onTap = () => context.go('/me/saves');
      } else if (item.targetType == 'EVENT_CARD' &&
          item.eventCardTarget != null) {
        title = item.eventCardTarget!.title;
        icon = Icons.event_outlined;
        onTap = () => context.go('/events/${item.targetId}');
      } else {
        continue;
      }
      tiles.add(
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PrismSpacing.xl,
            vertical: 2,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(PrismRadius.md),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: PrismColors.bgTint,
                        borderRadius: BorderRadius.circular(PrismRadius.sm + 2),
                      ),
                      child: Icon(icon, size: 18, color: PrismColors.ink2),
                    ),
                    const SizedBox(width: PrismSpacing.md),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: PrismColors.ink1,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: PrismColors.ink4,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return tiles;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          PrismSpacing.xl,
          PrismSpacing.lg,
          PrismSpacing.xl,
          PrismSpacing.sm,
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: PrismColors.ink1,
          ),
        ),
      );
}

class _OverlineHeader extends StatelessWidget {
  const _OverlineHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          PrismSpacing.xl,
          PrismSpacing.cardPad,
          PrismSpacing.xl,
          PrismSpacing.md,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: PrismColors.ink4,
          ),
        ),
      );
}

class _BandDivider extends StatelessWidget {
  const _BandDivider();
  @override
  Widget build(BuildContext context) => Container(
        height: 6,
        color: PrismColors.bgSoft,
      );
}

class _TopicHubStrip extends StatelessWidget {
  const _TopicHubStrip({required this.hubs});
  final List<TopicHubSummaryDto> hubs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          PrismSpacing.xl,
          0,
          PrismSpacing.xl,
          PrismSpacing.cardPad,
        ),
        itemCount: hubs.length,
        separatorBuilder: (_, _) => const SizedBox(width: PrismSpacing.cardPad),
        itemBuilder: (_, i) {
          final hub = hubs[i];
          return SizedBox(
            width: 64,
            child: GestureDetector(
              onTap: () => context.go('/categories/${hub.categorySlug}'),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TopicBlock(label: hub.title, size: 56),
                  const SizedBox(height: 6),
                  Text(
                    hub.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1.2,
                      color: PrismColors.ink2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HorizontalPostRow extends StatelessWidget {
  const _HorizontalPostRow({required this.posts});
  final List<PostDto> posts;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 192,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.xl),
          itemCount: posts.length,
          separatorBuilder: (_, _) => const SizedBox(width: PrismSpacing.md),
          itemBuilder: (_, i) => SizedBox(
            width: 280,
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
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.xl),
          itemCount: rooms.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final room = rooms[i];
            return ActionChip(
              avatar: const Icon(
                Icons.tag,
                size: 14,
                color: PrismColors.pp700,
              ),
              label: Text(room.name),
              onPressed: () => context.go('/rooms/${room.slug}'),
              backgroundColor: PrismColors.pp50,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: PrismColors.pp700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PrismRadius.pill),
                side: const BorderSide(color: PrismColors.pp100),
              ),
            );
          },
        ),
      );
}

class _HorizontalEventRow extends StatelessWidget {
  const _HorizontalEventRow({required this.events});
  final List<EventCardDto> events;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.xl),
          itemCount: events.length,
          separatorBuilder: (_, _) => const SizedBox(width: PrismSpacing.md),
          itemBuilder: (_, i) => SizedBox(
            width: 296,
            child: EventCardWidget(
              card: events[i],
              compact: true,
              onTap: () => context.go('/events/${events[i].id}'),
            ),
          ),
        ),
      );
}
