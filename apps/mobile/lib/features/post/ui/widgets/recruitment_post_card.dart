import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../../../widgets/status_pill.dart';
import '../../data/recruitment_fields_dto.dart';

/// Recruitment post card. Status pill in the header + structured field
/// rows + author-only status toggle action row.
///
/// Status labels (preserved from existing copy):
///   • OPEN   → "모집 중"
///   • CLOSED → "모집 마감"
///   • FILLED → "충원 완료"
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

  StatusPill _statusPill() {
    switch (fields.status) {
      case 'CLOSED':
        return StatusPill.neutral('모집 마감');
      case 'FILLED':
        return StatusPill.purple('충원 완료');
      default:
        return StatusPill.success('모집 중');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(PrismSpacing.cardPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign,
                    color: PrismColors.pp700, size: 18),
                const SizedBox(width: PrismSpacing.sm),
                const Text(
                  '스태프 모집',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: PrismColors.ink1,
                  ),
                ),
                const Spacer(),
                _statusPill(),
              ],
            ),
            const SizedBox(height: PrismSpacing.md),
            _Row(label: '역할', value: fields.role),
            _Row(label: '일정', value: fields.schedule),
            _Row(label: '장소', value: fields.location),
            _Row(label: '보상', value: fields.compensation),
            _Row(label: '인원', value: '${fields.capacity}명'),
            _Row(label: '지원 방법', value: fields.applicationMethod),
            if (isAuthor && onSetStatus != null) ...[
              const Divider(height: 24, color: PrismColors.divider),
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
                  const SizedBox(width: PrismSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: fields.status == 'FILLED'
                          ? null
                          : () => onSetStatus!('FILLED'),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('충원 완료'),
                    ),
                  ),
                  const SizedBox(width: PrismSpacing.sm),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                color: PrismColors.ink3,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                letterSpacing: -0.3,
                color: PrismColors.ink1,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
