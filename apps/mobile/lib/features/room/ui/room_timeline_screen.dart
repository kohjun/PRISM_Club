import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
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
    final composeIcon = useRecruitmentComposer
        ? Icons.campaign_outlined
        : Icons.edit;

    return Scaffold(
      appBar: AppBar(
        title: detail.maybeWhen(
          data: (d) => Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          orElse: () => const Text('방'),
        ),
        actions: [
          Consumer(builder: (ctx, ref, _) {
            final state = ref.watch(roomFollowProvider(roomSlug));
            final followed = state.valueOrNull?.followed ?? false;
            return TextButton(
              onPressed: state.isLoading
                  ? null
                  : () => ref
                      .read(roomFollowProvider(roomSlug).notifier)
                      .toggle(),
              child: Text(followed ? '팔로잉' : '팔로우'),
            );
          }),
        ],
      ),
      body: detail.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '방을 불러오지 못했어요.',
          onRetry: () => ref.invalidate(roomDetailProvider(roomSlug)),
        ),
        data: (room) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(roomDetailProvider(roomSlug));
            ref.invalidate(timelineProvider(roomSlug));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _RoomHeader(room: room),
              if (room.pins.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('대표 자료',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final pin in room.pins) ...[
                  if (pin.asEventCard != null)
                    EventCardWidget(
                      card: pin.asEventCard!,
                      onTap: () =>
                          context.go('/events/${pin.asEventCard!.id}'),
                    ),
                  if (pin.asReference != null)
                    ReferenceCardWidget(reference: pin.asReference!),
                  const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text('타임라인',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              timeline.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: LoadingView(),
                ),
                error: (e, _) => ErrorView(
                  message: e is ApiError ? e.message : '타임라인을 불러오지 못했어요.',
                  onRetry: () => ref.invalidate(timelineProvider(roomSlug)),
                ),
                data: (page) => page.items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: EmptyView(
                          message: '아직 글이 없어요. 첫 글을 남겨 보세요.',
                          action: FilledButton.icon(
                            icon: Icon(composeIcon),
                            label: Text(composeLabel),
                            onPressed: () => context.go(composePath),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (final post in page.items) ...[
                            PostCardWidget(
                              post: post,
                              onTap: () =>
                                  context.go('/posts/${post.id}'),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(composeIcon),
        label: Text(composeLabel),
        onPressed: () => context.go(composePath),
      ),
    );
  }
}

class _RoomHeader extends StatelessWidget {
  const _RoomHeader({required this.room});
  final RoomDetailDto room;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: PrismColors.soft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                room.origin == 'USER' ? '유저 생성' : '기본 방',
                style: const TextStyle(
                    fontSize: 11, color: PrismColors.primary),
              ),
            ),
            if (room.ownerNickname != null) ...[
              const SizedBox(width: 8),
              Text('by ${room.ownerNickname}',
                  style: const TextStyle(
                      fontSize: 12, color: PrismColors.muted)),
            ],
          ],
        ),
        if ((room.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(room.description!),
        ],
      ],
    );
  }
}
