import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../data/event_detail_dto.dart';

class EventReviewCard extends StatelessWidget {
  const EventReviewCard({super.key, required this.review});
  final EventReviewDto review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: PrismSpacing.md),
      padding: const EdgeInsets.all(PrismSpacing.lg),
      decoration: BoxDecoration(
        color: PrismColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PrismColors.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (int i = 0; i < 5; i += 1)
                Icon(
                  i < review.rating ? Icons.star : Icons.star_border,
                  color: i < review.rating
                      ? PrismColors.warningFg
                      : PrismColors.muted,
                  size: 16,
                ),
              const SizedBox(width: 8),
              Text(
                review.userNickname ?? '익명',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PrismColors.ink2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            review.body,
            style: const TextStyle(
              fontSize: 13,
              color: PrismColors.ink2,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
