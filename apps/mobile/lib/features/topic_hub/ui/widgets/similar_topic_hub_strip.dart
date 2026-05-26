import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../data/similar_hub_dto.dart';
import '../../data/similar_hub_repository.dart';

/// P7.1 — horizontal strip of "이 Hub를 보는 사람들이 같이 가는 Hub"
/// cards. Renders below the existing Topic Hub content (after the
/// related-rooms section). Empty / error / not-yet-computed responses
/// hide the strip so a fresh hub never shows a placeholder.
///
/// The card's reason chip ("@N명의 공통 기여자" / "공통 방 K개") is the
/// explainability surface — Club doesn't ship "this hub is similar
/// because the algorithm says so" without a human-readable why.
class SimilarTopicHubStrip extends ConsumerWidget {
  const SimilarTopicHubStrip({super.key, required this.hubSlug});

  final String hubSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(similarHubsProvider(hubSlug));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(
            top: PrismSpacing.lg,
            bottom: PrismSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PrismSpacing.xl,
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.hub_outlined,
                      size: 16,
                      color: PrismColors.pp700,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '이 Hub와 비슷한 Hub',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PrismColors.ink1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PrismSpacing.md),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: PrismSpacing.xl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: PrismSpacing.md),
                  itemBuilder: (_, i) => _SimilarHubCard(hub: items[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SimilarHubCard extends StatelessWidget {
  const _SimilarHubCard({required this.hub});

  final SimilarHubDto hub;

  @override
  Widget build(BuildContext context) {
    final reasonLine = _reasonLine(hub);
    return SizedBox(
      width: 220,
      child: Material(
        color: PrismColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: Key('similar-hub-${hub.slug}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/categories/${hub.categorySlug}'),
          child: Container(
            padding: const EdgeInsets.all(PrismSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PrismColors.pp200, width: 0.6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hub.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PrismColors.ink1,
                    height: 1.35,
                  ),
                ),
                const Spacer(),
                if (reasonLine != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: PrismColors.pp50,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      reasonLine,
                      style: const TextStyle(
                        fontSize: 11,
                        color: PrismColors.pp700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _reasonLine(SimilarHubDto hub) {
  // Prefer the stronger signal (contributors) when both are non-zero;
  // fall back to room overlap; null when neither is set so the chip
  // gracefully disappears.
  if (hub.sharedContributorCount > 0) {
    return '공통 기여자 ${hub.sharedContributorCount}명';
  }
  if (hub.sharedRoomCount > 0) {
    return '공통 방 ${hub.sharedRoomCount}개';
  }
  return null;
}
