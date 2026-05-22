import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../data/digest_dto.dart';
import '../../data/digest_repository.dart';

/// "이번 주 변화" rollup card (P2.4). Self-hides when the API returns
/// null (empty week) so a fresh hub doesn't render an empty section.
class WeeklyDigestSection extends ConsumerWidget {
  const WeeklyDigestSection({super.key, required this.categorySlug});

  final String categorySlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoryDigestProvider(categorySlug));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (digest) {
        if (digest == null || digest.payload.isEmpty) {
          return const SizedBox.shrink();
        }
        return _DigestCard(digest: digest);
      },
    );
  }
}

class _DigestCard extends StatelessWidget {
  const _DigestCard({required this.digest});
  final DigestDto digest;

  @override
  Widget build(BuildContext context) {
    final p = digest.payload;
    final periodLabel = _formatPeriod(digest.periodStart, digest.periodEnd);
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
                Icons.auto_awesome_outlined,
                size: 18,
                color: PrismColors.pp700,
              ),
              const SizedBox(width: 6),
              const Text(
                '이번 주 변화',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PrismColors.pp700,
                ),
              ),
              const Spacer(),
              Text(
                periodLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: PrismColors.muted,
                ),
              ),
            ],
          ),
          if (p.revisions.isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.md),
            _SubHeader(text: '지식 업데이트 ${p.revisions.length}건'),
            ...p.revisions
                .take(3)
                .map((r) => _BulletLine(text: _revisionLine(r))),
          ],
          if (p.newReferences.isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.md),
            _SubHeader(text: '새 레퍼런스 ${p.newReferences.length}건'),
            ...p.newReferences.take(3).map(
                  (r) => _BulletLine(text: _referenceLine(r)),
                ),
          ],
          if (p.newEvents.isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.md),
            _SubHeader(text: '새 이벤트 ${p.newEvents.length}건'),
            ...p.newEvents.take(3).map(
                  (e) => _BulletLine(text: '${e.title} · ${e.region}'),
                ),
          ],
          if (p.popularPosts.isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.md),
            _SubHeader(text: '인기 글 ${p.popularPosts.length}건'),
            for (final post in p.popularPosts.take(3))
              InkWell(
                onTap: () =>
                    GoRouter.of(context).go('/posts/${post.id}'),
                child: _BulletLine(text: post.snippet),
              ),
          ],
        ],
      ),
    );
  }

  String _revisionLine(DigestRevisionDto r) {
    final who = r.contributorNickname ?? '익명';
    return '${r.title}  ·  $who';
  }

  String _referenceLine(DigestReferenceDto r) {
    final src = r.sourceName ?? '';
    return src.isEmpty ? r.title : '${r.title}  ·  $src';
  }

  String _formatPeriod(DateTime start, DateTime end) {
    final s = start.toLocal();
    final e = end.toLocal().subtract(const Duration(seconds: 1));
    String mmdd(DateTime d) =>
        '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    return '${mmdd(s)} – ${mmdd(e)}';
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

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3, top: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: PrismColors.muted, height: 1.5),
          ),
          Expanded(
            child: Text(
              text,
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
    );
  }
}
