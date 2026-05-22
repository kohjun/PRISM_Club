import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/safe_route.dart';
import '../../../core/api_error.dart';
import '../../../widgets/event_card_widget.dart';
import '../../../widgets/reference_card_widget.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/topic_block.dart';
import '../../room/data/room_summary_dto.dart';
import '../../search/data/search_repository.dart';
import '../data/topic_hub_dto.dart';
import '../data/topic_hub_repository.dart';
import 'widgets/weekly_digest_section.dart';

class TopicHubScreen extends ConsumerWidget {
  const TopicHubScreen({
    super.key,
    required this.categorySlug,
    this.spaceSlug,
    this.returnTo,
  });

  final String categorySlug;

  /// Optional originating space slug, passed via `?spaceSlug=` when the
  /// user arrived from a CategoryListScreen. When present (and no
  /// safer signal exists) the back button returns to that space's
  /// category list.
  final String? spaceSlug;

  /// Optional originating internal route, passed via `?returnTo=` when
  /// the user arrived via `context.go` from a non-CategoryList surface
  /// (Home, Search, Profile, MyContributions). `context.go` clears the
  /// nav stack, so `canPop()` returns false and the screen otherwise
  /// has no way to know where the user came from. Only internal routes
  /// matching [isSafeInternalRoute] are honored.
  final String? returnTo;

  void _onBack(BuildContext context) {
    // 1. If the nav stack has something to pop (push-based nav), pop it.
    if (context.canPop()) {
      context.pop();
      return;
    }
    // 2. Honor an explicit returnTo from the origin screen, but only if
    //    it looks like a safe internal route. Drops external / malformed
    //    values silently so an attacker-controlled deep link can't
    //    redirect off-app.
    if (isSafeInternalRoute(returnTo)) {
      context.go(returnTo!);
      return;
    }
    // 3. Otherwise, if we have a space context (CategoryList-origin),
    //    return to that space's category list.
    if (spaceSlug != null && spaceSlug!.isNotEmpty) {
      context.go('/spaces/$spaceSlug/categories');
      return;
    }
    // 4. Last-resort fallback — `/home` is the user's default
    //    bottom-nav surface, friendlier than dropping them on
    //    `/spaces` with no context.
    context.go('/home');
  }

  /// Builds a route under this Topic Hub (composer / room creator /
  /// etc.) that preserves the Hub's own `spaceSlug` + `returnTo`
  /// context as query params. The receiving screen forwards those
  /// values when it navigates back to the Hub, so a round-trip
  /// (Home → Hub → Composer → cancel/submit → Hub → back) lands the
  /// user on `/home` again instead of falling through to the
  /// `/spaces` last-resort fallback.
  ///
  /// `extra` is merged in first so per-callsite params (e.g.
  /// `target_block_id`) survive alongside the preserved context.
  /// `returnTo` is validated against [isSafeInternalRoute]; bad values
  /// are dropped silently rather than propagated.
  String _composerRoute(String subpath, {Map<String, String>? extra}) {
    final params = <String, String>{};
    if (extra != null) params.addAll(extra);
    if (spaceSlug != null && spaceSlug!.isNotEmpty) {
      params['spaceSlug'] = spaceSlug!;
    }
    if (isSafeInternalRoute(returnTo)) {
      params['returnTo'] = returnTo!;
    }
    final path = '/categories/$categorySlug/$subpath';
    if (params.isEmpty) return path;
    return Uri(path: path, queryParameters: params).toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(topicHubProvider(categorySlug));

    return Scaffold(
      backgroundColor: PrismColors.bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          tooltip: '뒤로',
          onPressed: () => _onBack(context),
        ),
        title: const Text(
          'TOPIC HUB',
          style: TextStyle(
            color: PrismColors.pp700,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            tooltip: '검색',
            onPressed: () => context.go(
              '/search?categorySlug=${Uri.encodeQueryComponent(categorySlug)}',
            ),
          ),
        ],
      ),
      body: bundle.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : 'Topic Hub를 불러오지 못했어요.',
          onRetry: () => ref.invalidate(topicHubProvider(categorySlug)),
        ),
        data: (b) => RefreshIndicator(
          color: PrismColors.pp600,
          onRefresh: () async =>
              ref.invalidate(topicHubProvider(categorySlug)),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Hero(bundle: b)),
              // P2.4: "이번 주 변화" rollup. Self-hides when the API
              // returns null (empty week), so the card doesn't appear
              // on brand-new hubs.
              SliverToBoxAdapter(
                child: WeeklyDigestSection(categorySlug: categorySlug),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  PrismSpacing.xl,
                  0,
                  PrismSpacing.xl,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _RelatedSearches(categorySlug: categorySlug),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  PrismSpacing.xl,
                  PrismSpacing.md,
                  PrismSpacing.xl,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.go(_composerRoute('contributions/new')),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('정보 개선 제안'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _Section(
                  overline: '이 주제의 핵심 정보',
                  title: '핵심 정보',
                  children: [
                    for (final block in b.blocks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: PrismSpacing.md),
                        child: _KnowledgeBlockCard(
                          block: block,
                          onPropose: () => context.go(_composerRoute(
                            'contributions/new',
                            extra: {'target_block_id': block.id},
                          )),
                        ),
                      ),
                  ],
                ),
              ),
              if (b.signals.isNotEmpty)
                SliverToBoxAdapter(
                  child: _Section(
                    title: '데이터 신호',
                    children: [
                      for (final s in b.signals)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: PrismSpacing.sm),
                          child: _SignalRow(signal: s),
                        ),
                    ],
                  ),
                ),
              if (b.relatedEvents.isNotEmpty)
                SliverToBoxAdapter(
                  child: _Section(
                    title: '이 주제의 PRISM EVENT',
                    children: [
                      for (final e in b.relatedEvents)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: PrismSpacing.sm),
                          child: EventCardWidget(
                            card: e,
                            onTap: () => context.go('/events/${e.id}'),
                          ),
                        ),
                    ],
                  ),
                ),
              if (b.relatedReferences.isNotEmpty)
                SliverToBoxAdapter(
                  child: _Section(
                    title: '레퍼런스',
                    children: [
                      for (final r in b.relatedReferences)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: PrismSpacing.sm),
                          child: ReferenceCardWidget(reference: r),
                        ),
                    ],
                  ),
                ),
              SliverToBoxAdapter(
                child: _RoomsSection(
                  rooms: b.rooms,
                  onCreateRoom: () =>
                      context.go(_composerRoute('rooms/new')),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.only(bottom: PrismSpacing.xl4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.bundle});
  final TopicHubBundle bundle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.55, 1.0],
          colors: [
            PrismColors.pp50,
            PrismColors.bgSoft,
            PrismColors.bg,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.xl,
        PrismSpacing.sm,
        PrismSpacing.xl,
        PrismSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TopicBlock(label: bundle.categoryName, size: 64),
              const SizedBox(width: PrismSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${bundle.categoryName} ›',
                      style: const TextStyle(
                        color: PrismColors.ink4,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bundle.hubTitle ?? bundle.categoryName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1.15,
                        color: PrismColors.ink1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bundle.hubSummary != null && bundle.hubSummary!.isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.md),
            Text(
              bundle.hubSummary!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                letterSpacing: -0.2,
                color: PrismColors.ink2,
              ),
            ),
          ] else if (bundle.categoryDescription != null &&
              bundle.categoryDescription!.isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.md),
            Text(
              bundle.categoryDescription!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                letterSpacing: -0.2,
                color: PrismColors.ink2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    this.overline,
    required this.title,
    required this.children,
  });
  final String? overline;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.xl,
        PrismSpacing.xl2,
        PrismSpacing.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overline != null) ...[
            Row(
              children: [
                const Icon(Icons.menu_book_outlined,
                    size: 13, color: PrismColors.pp700),
                const SizedBox(width: 5),
                Text(
                  overline!,
                  style: const TextStyle(
                    color: PrismColors.pp700,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: PrismSpacing.sm),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: PrismColors.ink1,
            ),
          ),
          const SizedBox(height: PrismSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _KnowledgeBlockCard extends StatelessWidget {
  const _KnowledgeBlockCard({required this.block, this.onPropose});
  final KnowledgeBlockDto block;
  final VoidCallback? onPropose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PrismSpacing.cardPad),
      decoration: BoxDecoration(
        color: PrismColors.pp50,
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        border: Border.all(color: PrismColors.pp100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _blockLabel(block.blockType).toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: PrismColors.pp700,
                ),
              ),
              const Spacer(),
              if (onPropose != null)
                IconButton(
                  onPressed: onPropose,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: PrismColors.pp700,
                  ),
                  tooltip: '이 블록 개선 제안',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            block.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: PrismColors.ink1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            block.body,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.55,
              letterSpacing: -0.2,
              color: PrismColors.ink2,
            ),
          ),
        ],
      ),
    );
  }

  String _blockLabel(String type) {
    switch (type) {
      case 'OVERVIEW':
        return '개요';
      case 'POPULAR_FORMAT':
        return '포맷';
      case 'RECOMMENDED_PARTY_SIZE':
        return '인원';
      case 'MOOD_TIPS':
        return '팁';
      case 'FAQ':
        return 'FAQ';
      case 'CHECKLIST':
        return '체크리스트';
      case 'WARNING':
        return '주의';
      default:
        return type;
    }
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.signal});
  final TopicSignalDto signal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.md,
        vertical: PrismSpacing.md,
      ),
      decoration: BoxDecoration(
        color: PrismColors.bg,
        borderRadius: BorderRadius.circular(PrismRadius.md),
        border: Border.all(color: PrismColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_outlined,
              size: 16, color: PrismColors.pp700),
          const SizedBox(width: PrismSpacing.sm),
          Expanded(
            child: Text(
              signal.title,
              style: const TextStyle(
                fontSize: 13.5,
                letterSpacing: -0.3,
                color: PrismColors.ink1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            signal.displayValue,
            style: const TextStyle(
              color: PrismColors.pp700,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: -0.3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomsSection extends StatelessWidget {
  const _RoomsSection({required this.rooms, required this.onCreateRoom});
  final List<RoomSummaryDto> rooms;
  final VoidCallback onCreateRoom;

  @override
  Widget build(BuildContext context) {
    final official = rooms.where((r) => !r.isUserCreated).toList();
    final user = rooms.where((r) => r.isUserCreated).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.xl,
        PrismSpacing.xl2,
        PrismSpacing.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '이 주제의 방',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: PrismColors.ink1,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: onCreateRoom,
                style: FilledButton.styleFrom(
                  backgroundColor: PrismColors.pp600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.md),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('방 만들기'),
              ),
            ],
          ),
          const SizedBox(height: PrismSpacing.md),
          if (official.isNotEmpty) ...[
            const _RoomGroupLabel(label: '기본 방'),
            for (final r in official) _RoomTile(room: r),
          ],
          if (user.isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.sm),
            const _RoomGroupLabel(label: '유저가 만든 방'),
            for (final r in user) _RoomTile(room: r),
          ],
        ],
      ),
    );
  }
}

class _RoomGroupLabel extends StatelessWidget {
  const _RoomGroupLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: PrismColors.ink4,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room});
  final RoomSummaryDto room;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PrismSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(PrismRadius.md),
          onTap: () => context.go('/rooms/${room.slug}'),
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
                  width: 38,
                  height: 38,
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
                        room.name,
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
                        room.ownerNickname != null
                            ? '${room.ownerNickname} · ${_roomTypeLabel(room.roomType)}'
                            : _roomTypeLabel(room.roomType),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
    );
  }

  String _roomTypeLabel(String t) {
    switch (t) {
      case 'DISCUSSION':
        return '토론';
      case 'EVENT_REACTION':
        return '이벤트 반응';
      case 'REFERENCE':
        return '레퍼런스';
      case 'IDEA':
        return '아이디어';
      case 'RECRUITMENT':
        return '모집';
      case 'SOCIAL':
        return '소셜링';
      default:
        return t;
    }
  }
}

class _RelatedSearches extends ConsumerWidget {
  const _RelatedSearches({required this.categorySlug});
  final String categorySlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sugs = ref.watch(searchSuggestionsProvider(categorySlug));
    return sugs.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: PrismSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.search, size: 13, color: PrismColors.ink4),
                  SizedBox(width: 4),
                  Text(
                    '관련 검색',
                    style: TextStyle(
                      color: PrismColors.ink4,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PrismSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: items
                    .map(
                      (s) => Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => context.go(
                            '/search?q=${Uri.encodeQueryComponent(s)}&categorySlug=${Uri.encodeQueryComponent(categorySlug)}',
                          ),
                          borderRadius:
                              BorderRadius.circular(PrismRadius.pill),
                          child: Semantics(
                            button: true,
                            label: '관련 검색 $s',
                            child: Container(
                              constraints: const BoxConstraints(
                                minHeight: 44,
                                minWidth: 44,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: PrismColors.pp50,
                                borderRadius:
                                    BorderRadius.circular(PrismRadius.pill),
                                border:
                                    Border.all(color: PrismColors.pp100),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: PrismColors.pp700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
