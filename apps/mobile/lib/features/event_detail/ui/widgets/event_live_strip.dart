import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design_tokens.dart';
import '../../../../core/api_error.dart';
import '../../../../widgets/prism_avatar.dart';
import '../../data/event_live_repository.dart';

/// P6.8 — "현장 라이브" horizontal strip on EventDetail.
///
/// Reads `/v1/event-cards/:id/live`; the API only returns items to
/// callers whose RSVP=ATTENDED or GOING. We don't render the strip
/// at all when the response is empty so the EventDetail stays
/// uncluttered for casual visitors.
class EventLiveStrip extends ConsumerWidget {
  const EventLiveStrip({
    super.key,
    required this.eventCardId,
    this.onComposeTap,
  });

  final String eventCardId;

  /// Optional CTA — tapping it opens a small composer. When null the
  /// strip is read-only (used for non-ATTENDED viewers / archived
  /// events).
  final VoidCallback? onComposeTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(eventLiveListProvider(eventCardId));
    return live.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) {
        if (e is ApiError && e.statusCode == 404) {
          return const SizedBox.shrink();
        }
        // Don't surface a banner; live strip is a soft surface.
        return const SizedBox.shrink();
      },
      data: (items) {
        if (items.isEmpty && onComposeTap == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PrismSpacing.xl,
            vertical: PrismSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: PrismColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '현장 라이브',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: PrismColors.ink1,
                    ),
                  ),
                  const Spacer(),
                  if (onComposeTap != null)
                    TextButton.icon(
                      onPressed: onComposeTap,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('한 줄 남기기'),
                    ),
                ],
              ),
              const SizedBox(height: PrismSpacing.sm),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: PrismSpacing.sm),
                  itemBuilder: (_, i) => _LiveCard(item: items[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.item});
  final EventLivePostDto item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(PrismSpacing.cardPad),
      decoration: BoxDecoration(
        color: PrismColors.bg,
        borderRadius: BorderRadius.circular(PrismRadius.md),
        border: Border.all(color: PrismColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PrismAvatar(name: item.author.nickname, size: 22),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.author.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: PrismColors.ink2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              item.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: PrismColors.ink1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
