import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/event_card_widget.dart';
import '../../../widgets/post_card_widget.dart';
import '../../../widgets/reference_card_widget.dart';
import '../../../widgets/state_views.dart';
import '../../auth/data/me_repository.dart';
import '../../post/data/post_repository.dart';
import '../data/follow_repository.dart';
import '../data/room_detail_dto.dart';
import '../data/room_repository.dart';

class RoomTimelineScreen extends ConsumerWidget {
  const RoomTimelineScreen({super.key, required this.roomSlug});
  final String roomSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(roomDetailProvider(roomSlug));
    final timeline = ref.watch(timelineProvider(roomSlug));
    final me = ref.watch(meProvider).valueOrNull;
    final roomType = detail.valueOrNull?.roomType;
    final useRecruitmentComposer =
        roomType == 'RECRUITMENT' && (me?.isPlanner ?? false);
    final composePath = useRecruitmentComposer
        ? '/rooms/$roomSlug/compose-recruitment'
        : '/rooms/$roomSlug/compose';
    final composeLabel = useRecruitmentComposer ? '모집 글쓰기' : '글쓰기';
    final composeIcon =
        useRecruitmentComposer ? Icons.campaign_outlined : Icons.edit;

    return Scaffold(
      appBar: AppBar(
        title: detail.maybeWhen(
          data: (d) =>
              Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          orElse: () => const Text('방'),
        ),
        actions: [
          Consumer(
            builder: (ctx, ref, _) {
              final state = ref.watch(roomFollowProvider(roomSlug));
              final followed = state.valueOrNull?.followed ?? false;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 8,
                ),
                child: TextButton(
                  onPressed: state.isLoading
                      ? null
                      : () => ref
                          .read(roomFollowProvider(roomSlug).notifier)
                          .toggle(),
                  style: TextButton.styleFrom(
                    backgroundColor: followed
                        ? PrismColors.bgTint
                        : PrismColors.pp600,
                    foregroundColor: followed ? PrismColors.ink2 : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PrismRadius.pill),
                    ),
                  ),
                  child: Text(
                    followed ? '팔로잉' : '팔로우',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: detail.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '방을 불러오지 못했어요.',
          onRetry: () => ref.invalidate(roomDetailProvider(roomSlug)),
        ),
        data: (room) => RefreshIndicator(
          color: PrismColors.pp600,
          onRefresh: () async {
            ref.invalidate(roomDetailProvider(roomSlug));
            ref.invalidate(timelineProvider(roomSlug));
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _RoomHeader(room: room),
              if (room.pins.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    PrismSpacing.xl,
                    PrismSpacing.md,
                    PrismSpacing.xl,
                    PrismSpacing.cardPad,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom:
                          BorderSide(color: PrismColors.bgSoft, width: 6),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(PrismSpacing.md),
                    decoration: BoxDecoration(
                      color: PrismColors.pp50,
                      borderRadius: BorderRadius.circular(PrismRadius.md),
                      border: Border.all(
                        color: PrismColors.pp300,
                        width: 1,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.push_pin,
                                size: 14, color: PrismColors.pp700),
                            SizedBox(width: 5),
                            Text(
                              '고정된 안내',
                              style: TextStyle(
                                color: PrismColors.pp700,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: PrismSpacing.sm),
                        for (final pin in room.pins) ...[
                          if (pin.asEventCard != null)
                            EventCardWidget(
                              card: pin.asEventCard!,
                              compact: true,
                              onTap: () => context
                                  .go('/events/${pin.asEventCard!.id}'),
                            ),
                          if (pin.asReference != null)
                            ReferenceCardWidget(
                                reference: pin.asReference!, compact: true),
                          const SizedBox(height: 6),
                        ],
                      ],
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  PrismSpacing.xl,
                  PrismSpacing.cardPad,
                  PrismSpacing.xl,
                  PrismSpacing.sm,
                ),
                child: Text(
                  '타임라인',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: PrismColors.ink1,
                  ),
                ),
              ),
              timeline.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: PrismSpacing.xl3),
                  child: LoadingView(),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(PrismSpacing.xl),
                  child: ErrorView(
                    message:
                        e is ApiError ? e.message : '타임라인을 불러오지 못했어요.',
                    onRetry: () => ref.invalidate(timelineProvider(roomSlug)),
                  ),
                ),
                data: (page) => page.items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: PrismSpacing.xl3),
                        child: EmptyView(
                          message: '아직 글이 없어요. 첫 글을 남겨 보세요.',
                          action: FilledButton.icon(
                            icon: Icon(composeIcon),
                            label: Text(composeLabel),
                            onPressed: () => context.go(composePath),
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(
                          PrismSpacing.xl,
                          0,
                          PrismSpacing.xl,
                          PrismSpacing.lg,
                        ),
                        child: Column(
                          children: [
                            for (final post in page.items) ...[
                              PostCardWidget(
                                post: post,
                                onTap: () => context.go('/posts/${post.id}'),
                                onAuthorTap: (uid) =>
                                    context.go('/users/$uid'),
                              ),
                              const SizedBox(height: PrismSpacing.md),
                            ],
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: PrismElevation.brand,
        ),
        child: FloatingActionButton(
          backgroundColor: PrismColors.pp700,
          foregroundColor: Colors.white,
          elevation: 0,
          onPressed: () => context.go(composePath),
          tooltip: composeLabel,
          child: Icon(composeIcon, size: 24),
        ),
      ),
    );
  }
}

class _RoomHeader extends StatelessWidget {
  const _RoomHeader({required this.room});
  final RoomDetailDto room;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PrismSpacing.xl,
        PrismSpacing.md,
        PrismSpacing.xl,
        PrismSpacing.cardPad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: PrismColors.pp50,
                  borderRadius: BorderRadius.circular(PrismRadius.xs + 1),
                ),
                child: Text(
                  room.origin == 'USER' ? '유저 생성' : '기본 방',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: PrismColors.pp700,
                  ),
                ),
              ),
              if (room.ownerNickname != null) ...[
                const SizedBox(width: PrismSpacing.sm),
                Text(
                  'by ${room.ownerNickname}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PrismColors.ink4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          if ((room.description ?? '').isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.md),
            Text(
              room.description!,
              style: const TextStyle(
                fontSize: 13.5,
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
