import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../data/recruitment_fields_dto.dart';

/// Renders a RECRUITMENT post's structured fields with a status chip header.
/// When [isAuthor] is true, an action row exposes status toggles
/// (OPEN → CLOSED / FILLED). Callers wire [onSetStatus] to call
/// `PostRepository.setRecruitmentStatus`.
class RecruitmentPostCard extends StatelessWidget {
  const RecruitmentPostCard({
    super.key,
    required this.fields,
    required this.isAuthor,
    required this.onSetStatus,
  });

  final RecruitmentFieldsDto fields;
  final bool isAuthor;
  final Future<void> Function(String status)? onSetStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign, color: PrismColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  '스태프 모집',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                _StatusChip(status: fields.status),
              ],
            ),
            const SizedBox(height: 12),
            _Row(label: '역할', value: fields.role),
            _Row(label: '일정', value: fields.schedule),
            _Row(label: '장소', value: fields.location),
            _Row(label: '보상', value: fields.compensation),
            _Row(label: '인원', value: '${fields.capacity}명'),
            _Row(label: '지원 방법', value: fields.applicationMethod),
            if (isAuthor && onSetStatus != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: fields.status == 'CLOSED'
                          ? null
                          : () => onSetStatus!('CLOSED'),
                      icon: const Icon(Icons.lock_outline, size: 16),
                      label: const Text('모집 마감'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: fields.status == 'FILLED'
                          ? null
                          : () => onSetStatus!('FILLED'),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('충원 완료'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: fields.status == 'OPEN'
                          ? null
                          : () => onSetStatus!('OPEN'),
                      icon: const Icon(Icons.lock_open_outlined, size: 16),
                      label: const Text('다시 열기'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(color: PrismColors.muted, fontSize: 12),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
      'CLOSED' => ('모집 마감', PrismColors.muted, PrismColors.border),
      'FILLED' => ('충원 완료', PrismColors.primary, PrismColors.soft),
      _ => ('모집 중', Colors.white, PrismColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
