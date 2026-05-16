import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../data/search_dto.dart';

/// Shown when the user taps an EventCard search result. EventCard has no
/// dedicated detail screen, so we render its key fields inline.
Future<void> showEventInfoSheet(BuildContext context, SearchHitDto hit) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: PrismColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: PrismColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.event, color: PrismColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hit.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _EventStatusChip(status: hit.ctxString('event_status') ?? ''),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(label: '장소', value: hit.ctxString('venue_name')),
          _InfoRow(label: '지역', value: hit.ctxString('region')),
          _InfoRow(label: '일시', value: _fmtDate(hit.ctxString('starts_at'))),
          _InfoRow(label: '이벤트 ID', value: hit.ctxString('external_event_id')),
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(color: PrismColors.muted, fontSize: 12)),
          ),
          Expanded(child: Text(value!)),
        ],
      ),
    );
  }
}

class _EventStatusChip extends StatelessWidget {
  const _EventStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final completed = status == 'COMPLETED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: completed ? PrismColors.border : PrismColors.soft,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        completed ? '진행 완료' : '진행 예정',
        style: TextStyle(
          fontSize: 11,
          color: completed ? PrismColors.muted : PrismColors.primary,
        ),
      ),
    );
  }
}

String? _fmtDate(String? iso) {
  if (iso == null) return null;
  try {
    final t = DateTime.parse(iso);
    return '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}
