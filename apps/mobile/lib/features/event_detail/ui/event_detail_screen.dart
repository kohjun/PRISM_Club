import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/post_card_widget.dart';
import '../../../widgets/state_views.dart';
import '../../event_card/data/event_card_dto.dart';
import '../../post/data/post_dto.dart';
import '../../saves/data/saves_repository.dart';
import '../data/event_detail_dto.dart';
import '../data/event_detail_repository.dart';
import 'widgets/compose_room_picker.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.cardId});
  final String cardId;

  @override
  ConsumerState<EventDetailScreen> createState() =>
      _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  /// Scroll offset at which we hand the AppBar over to its "content" state
  /// — solid white background + ink-1 icons + visible title. Below this,
  /// the app bar stays transparent over the gradient hero.
  ///
  /// The hero is 320px tall and the floating date card is offset -32, so
  /// content effectively starts around y = 288. We trigger a bit earlier
  /// (240) so the title fades in cleanly while the hero is still
  /// scrolling out.
  static const double _heroFadeThreshold = 240;

  bool _overContent = false;

  void _onScroll(double offset) {
    final next = offset > _heroFadeThreshold;
    if (next != _overContent) {
      setState(() => _overContent = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundle = ref.watch(eventDetailProvider(widget.cardId));

    return Scaffold(
      backgroundColor: PrismColors.bg,
      extendBodyBehindAppBar: true,
      appBar: _EventAppBar(
        title: bundle.maybeWhen(
          data: (b) => b.eventCard.title,
          orElse: () => '이벤트',
        ),
        cardId: widget.cardId,
        overContent: _overContent,
      ),
      body: bundle.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: kToolbarHeight),
          child: LoadingView(),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: kToolbarHeight),
          child: ErrorView(
            message: e is ApiError ? e.message : '이벤트 정보를 불러오지 못했어요.',
            onRetry: () =>
                ref.invalidate(eventDetailProvider(widget.cardId)),
          ),
        ),
        data: (b) => RefreshIndicator(
          color: PrismColors.pp600,
          onRefresh: () async =>
              ref.invalidate(eventDetailProvider(widget.cardId)),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis == Axis.vertical) {
                _onScroll(n.metrics.pixels);
              }
              return false;
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Hero(card: b.eventCard)),
                SliverToBoxAdapter(child: _DateVenueCard(card: b.eventCard)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    PrismSpacing.xl,
                    PrismSpacing.lg,
                    PrismSpacing.xl,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _RelatedRoomsSection(rooms: b.relatedRooms),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    PrismSpacing.xl,
                    PrismSpacing.xl,
                    PrismSpacing.xl,
                    100,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _RelatedPostsSection(
                      posts: b.relatedPosts,
                      postCount: b.postCount,
                    ),
                  ),
                ),
              ],
            ),
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

/// AppBar that swaps between two states without rebuilding the whole
/// route. Over the gradient hero: transparent background + white
/// icons + invisible title. Over content: solid white background +
/// ink-1 icons + visible title + a hairline bottom border.
class _EventAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _EventAppBar({
    required this.title,
    required this.cardId,
    required this.overContent,
  });

  final String title;
  final String cardId;
  final bool overContent;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final iconColor = overContent ? PrismColors.ink1 : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: overContent ? PrismColors.bg : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: overContent ? PrismColors.line : Colors.transparent,
          ),
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: iconColor,
        iconTheme: IconThemeData(color: iconColor),
        title: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          opacity: overContent ? 1 : 0,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: iconColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ),
        actions: [
          Consumer(
            builder: (ctx, ref, _) {
              final saveKey = 'EVENT_CARD:$cardId';
              final saved =
                  ref.watch(saveStateProvider(saveKey)).valueOrNull ?? false;
              return IconButton(
                icon: Icon(
                  saved ? Icons.bookmark : Icons.bookmark_outline,
                  color: iconColor,
                ),
                tooltip: saved ? '저장 취소' : '저장',
                onPressed: () => ref
                    .read(saveStateProvider(saveKey).notifier)
                    .toggle(),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.card});
  final EventCardDto card;

  static const _monthAbbrevs = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.6, 1.0],
          colors: [PrismColors.pp700, PrismColors.pp500, PrismColors.pp300],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PrismSpacing.xl2,
            56,
            PrismSpacing.xl2,
            PrismSpacing.xl3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(PrismRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'PRISM EVENT · 오프라인 모임',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PrismSpacing.md),
              Text(
                card.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: PrismSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.tag, size: 13, color: Colors.white70),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      card.region,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String monthOf(DateTime t) => _monthAbbrevs[t.month - 1];
}

class _DateVenueCard extends StatelessWidget {
  const _DateVenueCard({required this.card});
  final EventCardDto card;

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final t = card.startsAt;
    final dateLine =
        '${t.year}. ${t.month}. ${t.day} (${_weekdayKr(t.weekday)}) '
        '${_two(t.hour)}:${_two(t.minute)}';

    return Transform.translate(
      offset: const Offset(0, -32),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.xl),
        child: Container(
          padding: const EdgeInsets.all(PrismSpacing.lg),
          decoration: BoxDecoration(
            color: PrismColors.bg,
            borderRadius: BorderRadius.circular(PrismRadius.lg),
            border: Border.all(color: PrismColors.line),
            boxShadow: PrismElevation.raised,
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PrismColors.pp50,
                  borderRadius: BorderRadius.circular(PrismRadius.md),
                  border: Border.all(color: PrismColors.pp100),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _Hero.monthOf(t),
                      style: const TextStyle(
                        color: PrismColors.pp700,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${t.day}',
                      style: const TextStyle(
                        color: PrismColors.ink1,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: PrismSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dateLine,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: PrismColors.ink1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: PrismColors.ink3),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '${card.venueName} · ${card.region}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: PrismColors.ink3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _weekdayKr(int weekday) {
    const names = ['월', '화', '수', '목', '금', '토', '일'];
    return names[weekday - 1];
  }
}

class _RelatedRoomsSection extends StatelessWidget {
  const _RelatedRoomsSection({required this.rooms});
  final List<RelatedRoomDto> rooms;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '관련 방 (${rooms.length})',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: PrismColors.ink1,
          ),
        ),
        const SizedBox(height: PrismSpacing.md),
        for (final r in rooms)
          Padding(
            padding: const EdgeInsets.only(bottom: PrismSpacing.sm),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(PrismRadius.md),
                onTap: () => context.go('/rooms/${r.slug}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PrismSpacing.cardPad,
                    vertical: PrismSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: PrismColors.bg,
                    borderRadius: BorderRadius.circular(PrismRadius.md),
                    border: Border.all(color: PrismColors.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: PrismColors.bgTint,
                          borderRadius: BorderRadius.circular(PrismRadius.md),
                        ),
                        child: const Icon(Icons.tag,
                            color: PrismColors.ink2, size: 18),
                      ),
                      const SizedBox(width: PrismSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: PrismColors.ink1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.relation == 'PIN'
                                  ? '대표 자료로 고정'
                                  : '이 이벤트가 첨부된 글이 있는 방',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: PrismColors.ink4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: PrismColors.ink4, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
        Text(
          '관련 글 ($postCount)',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: PrismColors.ink1,
          ),
        ),
        const SizedBox(height: PrismSpacing.md),
        if (posts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: PrismSpacing.xl2),
            child: EmptyView(
              message: '아직 이 이벤트로 작성된 글이 없어요.\n첫 글을 남겨 보세요.',
            ),
          )
        else
          for (final p in posts) ...[
            PostCardWidget(
              post: p,
              onTap: () => context.go('/posts/${p.id}'),
              onAuthorTap: (uid) => context.go('/users/$uid'),
            ),
            const SizedBox(height: PrismSpacing.sm),
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PrismRadius.pill),
        boxShadow: _enabled ? PrismElevation.brand : null,
      ),
      child: FloatingActionButton.extended(
        elevation: 0,
        backgroundColor: _enabled ? PrismColors.pp700 : PrismColors.line,
        foregroundColor: _enabled ? Colors.white : PrismColors.ink4,
        icon: const Icon(Icons.edit, size: 18),
        label: const Text(
          '글 작성',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        onPressed: _enabled ? () => _onPressed(context) : null,
      ),
    );
  }
}
