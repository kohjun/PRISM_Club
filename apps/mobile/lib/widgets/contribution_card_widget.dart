import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../features/knowledge/data/contribution_dto.dart';

class ContributionCardWidget extends StatelessWidget {
  const ContributionCardWidget({
    super.key,
    required this.contribution,
    this.onTap,
  });

  final ContributionDto contribution;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(status: contribution.status),
                  const SizedBox(width: 8),
                  if (contribution.isNewBlockProposal)
                    const _Tag(text: '새 블록', color: PrismColors.primary),
                  if (contribution.isNewBlockProposal) const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      contribution.proposedTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    contribution.contributor.nickname,
                    style: const TextStyle(
                        fontSize: 12, color: PrismColors.muted),
                  ),
                  const Text(' · ',
                      style: TextStyle(color: PrismColors.muted)),
                  Text(
                    _relativeTime(contribution.createdAt),
                    style: const TextStyle(
                        fontSize: 12, color: PrismColors.muted),
                  ),
                  if (contribution.hasEvidence) ...[
                    const SizedBox(width: 8),
                    Icon(
                      contribution.evidenceType == 'EVENT_CARD'
                          ? Icons.event
                          : Icons.link,
                      size: 12,
                      color: PrismColors.primary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg)),
    );
  }

  (String, Color, Color) _statusStyle(String s) {
    switch (s) {
      case ContributionStatus.pending:
        return ('대기', PrismColors.primary, PrismColors.soft);
      case ContributionStatus.approved:
        return ('승인됨', Colors.white, Colors.green);
      case ContributionStatus.rejected:
        return ('거절됨', Colors.white, Colors.redAccent);
      case ContributionStatus.needsChanges:
        return ('보완 요청', Colors.white, Colors.orange);
      case ContributionStatus.withdrawn:
        return ('철회됨', PrismColors.muted, PrismColors.border);
      default:
        return (s, PrismColors.muted, PrismColors.border);
    }
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: PrismColors.soft,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
