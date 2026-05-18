import 'package:flutter/material.dart';

import '../app/design_tokens.dart';
import '../features/knowledge/data/contribution_dto.dart';
import 'status_pill.dart';

/// Knowledge contribution card — appears in the curation queue, my-contributions
/// list, and curation detail header. Status pill + optional "새 블록" tag +
/// proposed title + contributor + relative time + evidence icon.
class ContributionCardWidget extends StatelessWidget {
  const ContributionCardWidget({
    super.key,
    required this.contribution,
    this.onTap,
    this.onAuthorTap,
  });

  final ContributionDto contribution;
  final VoidCallback? onTap;
  final ValueChanged<String>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(PrismSpacing.cardPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _statusPillFor(contribution.status),
                  const SizedBox(width: PrismSpacing.sm),
                  if (contribution.isNewBlockProposal) ...[
                    StatusPill.purple('새 블록'),
                    const SizedBox(width: PrismSpacing.xs),
                  ],
                  Expanded(
                    child: Text(
                      contribution.proposedTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: PrismColors.ink1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PrismSpacing.sm),
              Row(
                children: [
                  if (onAuthorTap != null)
                    InkWell(
                      onTap: () => onAuthorTap!(contribution.contributor.id),
                      borderRadius: BorderRadius.circular(PrismRadius.xs),
                      child: Text(
                        contribution.contributor.nickname,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PrismColors.ink3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Text(
                      contribution.contributor.nickname,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PrismColors.ink3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const Text(
                    ' · ',
                    style: TextStyle(color: PrismColors.ink4, fontSize: 12),
                  ),
                  Text(
                    _relativeTime(contribution.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: PrismColors.ink4,
                    ),
                  ),
                  if (contribution.hasEvidence) ...[
                    const SizedBox(width: PrismSpacing.sm),
                    Icon(
                      contribution.evidenceType == 'EVENT_CARD'
                          ? Icons.event
                          : Icons.link,
                      size: 13,
                      color: PrismColors.pp700,
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

  StatusPill _statusPillFor(String status) {
    switch (status) {
      case ContributionStatus.pending:
        return StatusPill.purple('대기');
      case ContributionStatus.approved:
        return StatusPill.success('승인됨');
      case ContributionStatus.rejected:
        return StatusPill.danger('거절됨');
      case ContributionStatus.needsChanges:
        return StatusPill.warning('보완 요청');
      case ContributionStatus.withdrawn:
        return StatusPill.neutral('철회됨');
      default:
        return StatusPill.neutral(status);
    }
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
