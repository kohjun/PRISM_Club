import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../data/event_digest_dto.dart';
import '../../data/event_digest_repository.dart';

/// Post-event "Recap" card (P3.5). Self-hides for non-COMPLETED events
/// (API returns null) and for events where neither posts nor reviews
/// landed in the recap window.
class EventRecapSection extends ConsumerWidget {
  const EventRecapSection({
    super.key,
    required this.eventCardId,
    required this.eventStatus,
  });

  final String eventCardId;
  final String eventStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (eventStatus != 'COMPLETED') return const SizedBox.shrink();
    final async = ref.watch(eventRecapProvider(eventCardId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (digest) {
        if (digest == null || digest.payload.isEmpty) {
          return const SizedBox.shrink();
        }
        return _RecapCard(digest: digest);
      },
    );
  }
}

class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.digest});
  final EventDigestDto digest;

  @override
  Widget build(BuildContext context) {
    final p = digest.payload;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.xl,
        vertical: PrismSpacing.md,
      ),
      padding: const EdgeInsets.all(PrismSpacing.lg),
      decoration: BoxDecoration(
        color: PrismColors.pp50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PrismColors.pp200, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.replay_circle_filled_outlined,
                color: PrismColors.pp700,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                '이벤트 Recap',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PrismColors.pp700,
                ),
              ),
              const Spacer(),
              if (p.averageRating != null)
                Text(
                  '★ ${p.averageRating!.toStringAsFixed(1)} · ${p.reviewCount}개',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PrismColors.muted,
                  ),
                ),
            ],
          ),
          if (p.topReviews.isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.md),
            const _SubHeader(text: '베스트 후기'),
            for (final r in p.topReviews.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 3, top: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '★ ${r.rating}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PrismColors.warningFg,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${r.snippet}${r.userNickname != null ? '  — ${r.userNickname}' : ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: PrismColors.ink2,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (p.topPosts.isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.md),
            const _SubHeader(text: '인기 글'),
            for (final post in p.topPosts.take(3))
              InkWell(
                onTap: () =>
                    GoRouter.of(context).go('/posts/${post.id}'),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3, top: 1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(
                          color: PrismColors.muted,
                          height: 1.5,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          post.snippet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: PrismColors.ink2,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  const _SubHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: PrismColors.ink2,
        ),
      ),
    );
  }
}
