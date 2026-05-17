import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../features/event_card/data/event_card_dto.dart';

class EventCardWidget extends StatelessWidget {
  const EventCardWidget({
    super.key,
    required this.card,
    this.compact = false,
    this.onTap,
  });

  final EventCardDto card;
  final bool compact;

  /// Optional tap handler. When omitted, the card renders as a passive chip
  /// (e.g., inside the composer attachment tile where a close button owns
  /// interaction). M5: callers in TopicHub / RoomTimeline / PostDetail /
  /// Search wire this to navigate to `/events/<card.id>`.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${card.startsAt.year}.${_two(card.startsAt.month)}.${_two(card.startsAt.day)}';

    final body = Padding(
      padding: EdgeInsets.all(compact ? 10 : 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PrismColors.soft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.event,
                color: PrismColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(card.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: card.isCompleted
                            ? PrismColors.border
                            : PrismColors.soft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        card.isCompleted ? '진행 완료' : '진행 예정',
                        style: TextStyle(
                          fontSize: 10,
                          color: card.isCompleted
                              ? PrismColors.muted
                              : PrismColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr · ${card.venueName} · ${card.region}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: PrismColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Card(
      child: onTap == null
          ? body
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: body,
            ),
    );
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
