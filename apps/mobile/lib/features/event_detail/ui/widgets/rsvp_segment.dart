import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design_tokens.dart';
import '../../../../core/api_error.dart';
import '../../data/event_detail_dto.dart';
import '../../data/event_detail_repository.dart';
import '../../data/rsvp_repository.dart';

/// Three-state RSVP control on the EventDetail header.
///
///   관심 있음 (INTERESTED) — soft commitment, fanout target for
///                            EVENT_UPDATED but not for reminders.
///   참석 예정 (GOING)       — reminder fanout target.
///   참석함   (ATTENDED)    — only enabled after the event has started.
///
/// Tapping the currently-selected button removes the RSVP entirely
/// (server DELETE). The bundle's `rsvp` payload is the source of truth;
/// after every write we invalidate the bundle provider so counts +
/// my_status come back in sync.
class RsvpSegment extends ConsumerStatefulWidget {
  const RsvpSegment({
    super.key,
    required this.eventCardId,
    required this.rsvp,
    required this.eventStatus,
    required this.startsAt,
  });

  final String eventCardId;
  final RsvpStateDto rsvp;
  final String eventStatus;
  final DateTime startsAt;

  @override
  ConsumerState<RsvpSegment> createState() => _RsvpSegmentState();
}

class _RsvpSegmentState extends ConsumerState<RsvpSegment> {
  bool _busy = false;

  bool get _attendedAllowed =>
      widget.eventStatus == 'COMPLETED' ||
      widget.startsAt.isBefore(DateTime.now());

  Future<void> _set(String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final current = widget.rsvp.myStatus;
      if (current == status) {
        // Toggle off — tap on the active button = remove.
        await ref.read(rsvpRepositoryProvider).remove(widget.eventCardId);
      } else {
        await ref
            .read(rsvpRepositoryProvider)
            .setRsvp(widget.eventCardId, status);
      }
      ref.invalidate(eventDetailProvider(widget.eventCardId));
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('RSVP 실패: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rsvp;
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
              Expanded(
                child: _SegButton(
                  label: '관심',
                  count: r.interestedCount,
                  active: r.myStatus == 'INTERESTED',
                  enabled: !_busy,
                  onTap: () => _set('INTERESTED'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SegButton(
                  label: '참석 예정',
                  count: r.goingCount,
                  active: r.myStatus == 'GOING',
                  enabled: !_busy,
                  onTap: () => _set('GOING'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SegButton(
                  label: '참석함',
                  count: r.attendedCount,
                  active: r.myStatus == 'ATTENDED',
                  enabled: !_busy && _attendedAllowed,
                  onTap: () => _set('ATTENDED'),
                ),
              ),
            ],
          ),
          if (!_attendedAllowed) ...[
            const SizedBox(height: 6),
            const Text(
              '참석함은 이벤트 시작 이후에만 표시할 수 있어요.',
              style: TextStyle(
                fontSize: 11,
                color: PrismColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  const _SegButton({
    required this.label,
    required this.count,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active ? PrismColors.pp600 : PrismColors.bg;
    final fg = active ? Colors.white : PrismColors.ink2;
    final border = active ? PrismColors.pp600 : PrismColors.line;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  color: fg.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
