import 'package:flutter/material.dart';

import '../app/design_tokens.dart';
import '../features/event_card/data/event_card_dto.dart';
import 'status_pill.dart';

/// PRISM EVENT card — appears inside posts, Topic Hub event sections,
/// search hits, EventDetail's "linked rooms / related posts" surfaces.
///
/// Two layouts:
/// • Standard (default): date block + overline + title + meta + status pill.
/// • Compact (`compact: true`): a tight pill row used inside post bodies
///   and the composer's "attached event" tile — same data, less paint.
///
/// The big gradient-hero variant for `EventDetailScreen` is rendered inline
/// in that screen (background gradient depends on the screen layout, not
/// the card itself).
class EventCardWidget extends StatelessWidget {
  const EventCardWidget({
    super.key,
    required this.card,
    this.compact = false,
    this.onTap,
  });

  final EventCardDto card;
  final bool compact;
  final VoidCallback? onTap;

  static const _monthAbbrevs = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final body = compact ? _CompactLayout(card: card) : _InlineLayout(card: card);

    final container = Container(
      decoration: BoxDecoration(
        color: PrismColors.pp50,
        borderRadius: BorderRadius.circular(PrismRadius.md),
        border: Border.all(color: PrismColors.pp100),
      ),
      child: body,
    );

    if (onTap == null) return container;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PrismRadius.md),
        onTap: onTap,
        child: container,
      ),
    );
  }

  static String monthOf(DateTime t) => _monthAbbrevs[t.month - 1];
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date, this.width = 50, this.height = 56});
  final DateTime date;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final monoSize = height >= 56 ? 22.0 : 18.0;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: PrismColors.bg,
        borderRadius: BorderRadius.circular(PrismRadius.sm),
        border: Border.all(color: PrismColors.pp100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            EventCardWidget.monthOf(date),
            style: const TextStyle(
              color: PrismColors.pp700,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${date.day}',
            style: TextStyle(
              color: PrismColors.ink1,
              fontSize: monoSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLayout extends StatelessWidget {
  const _InlineLayout({required this.card});
  final EventCardDto card;

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final t = card.startsAt;
    final timeStr = '${t.hour.toString().padLeft(2, '0')}:${_two(t.minute)}';
    final dateStr = '${t.month}/${t.day}';

    return Padding(
      padding: const EdgeInsets.all(PrismSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DateBlock(date: t),
          const SizedBox(width: PrismSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PRISM EVENT',
                  style: TextStyle(
                    color: PrismColors.pp700,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.3,
                    color: PrismColors.ink1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$dateStr $timeStr · ${card.venueName} · ${card.region}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: PrismColors.ink3,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: PrismSpacing.sm),
          StatusPill.event(card.eventStatus),
        ],
      ),
    );
  }
}

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({required this.card});
  final EventCardDto card;

  @override
  Widget build(BuildContext context) {
    final t = card.startsAt;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          _DateBlock(date: t, width: 40, height: 44),
          const SizedBox(width: PrismSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PRISM EVENT',
                  style: TextStyle(
                    color: PrismColors.pp700,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  card.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.3,
                    color: PrismColors.ink1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t.month}/${t.day} · ${card.venueName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: PrismColors.ink3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
