import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../data/memories_repository.dart';

/// P6.11 — "오늘의 기록" home top card. Self-hides on loading / error /
/// empty so it never parks a placeholder on a day with no anniversary
/// activity. Tapping opens the full memories screen.
class MemoriesCard extends ConsumerWidget {
  const MemoriesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todayMemoriesProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (memories) {
        if (memories.isEmpty) return const SizedBox.shrink();
        final lead = memories.items.first;
        final more = memories.items.length - 1;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            PrismSpacing.xl,
            PrismSpacing.lg,
            PrismSpacing.xl,
            PrismSpacing.sm,
          ),
          child: Material(
            color: PrismColors.pp50,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: const Key('memories-card'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/me/memories'),
              child: Container(
                padding: const EdgeInsets.all(PrismSpacing.lg),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PrismColors.pp200, width: 0.6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome,
                            size: 16, color: PrismColors.pp700),
                        SizedBox(width: 6),
                        Text(
                          '오늘의 기록',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: PrismColors.pp700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lead.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PrismColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lead.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PrismColors.ink1,
                      ),
                    ),
                    if (more > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        '외 $more건 더 보기',
                        style: const TextStyle(
                          fontSize: 12,
                          color: PrismColors.pp700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
