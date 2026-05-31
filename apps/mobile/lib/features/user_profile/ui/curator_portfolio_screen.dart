import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../widgets/state_views.dart';
import '../data/curator_portfolio_dto.dart';
import '../data/curator_portfolio_repository.dart';

/// P6.10 — a curator's portfolio: reputation summary, the contributions
/// they resolved, and the source-tier rules they introduced.
class CuratorPortfolioScreen extends ConsumerWidget {
  const CuratorPortfolioScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(curatorPortfolioProvider(userId));
    return Scaffold(
      appBar: AppBar(title: const Text('큐레이터 포트폴리오')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '포트폴리오를 불러오지 못했어요: $e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: PrismColors.muted),
            ),
          ),
        ),
        data: (p) {
          if (p.isEmpty) {
            return const EmptyView(
              message: '아직 모인 큐레이션 기록이 없어요.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (p.reputation != null) _ReputationCard(rep: p.reputation!),
              if (p.resolvedContributions.isNotEmpty) ...[
                const SizedBox(height: PrismSpacing.lg),
                const _SectionHeader(text: '검수한 기여'),
                ...p.resolvedContributions.map(
                  (c) => _ContributionTile(contribution: c),
                ),
              ],
              if (p.sourceRules.isNotEmpty) ...[
                const SizedBox(height: PrismSpacing.lg),
                const _SectionHeader(text: '도입한 출처 규칙'),
                ...p.sourceRules.map((r) => _RuleTile(rule: r)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: PrismSpacing.sm),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: PrismColors.ink2,
          ),
        ),
      );
}

class _ReputationCard extends StatelessWidget {
  const _ReputationCard({required this.rep});
  final CuratorReputationDto rep;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PrismSpacing.lg),
      decoration: BoxDecoration(
        color: PrismColors.pp50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PrismColors.pp200, width: 0.6),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '검수 점수',
                style: TextStyle(fontSize: 12, color: PrismColors.muted),
              ),
              const SizedBox(height: 2),
              Text(
                rep.weightedScore.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: PrismColors.pp700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '승인 ${rep.approvedCount} · 보류 ${rep.needsChangesCount}\n'
            '반려 ${rep.rejectedCount} · 철회 ${rep.withdrawnCount}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              color: PrismColors.ink2,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContributionTile extends StatelessWidget {
  const _ContributionTile({required this.contribution});
  final ResolvedContributionDto contribution;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: PrismColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: Key('portfolio-contribution-${contribution.id}'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.push('/categories/${contribution.categorySlug}'),
          child: Container(
            padding: const EdgeInsets.all(PrismSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PrismColors.border, width: 0.6),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined,
                    size: 18, color: PrismColors.pp700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    contribution.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PrismColors.ink1,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: PrismColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule});
  final SourceRuleDto rule;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(PrismSpacing.md),
        decoration: BoxDecoration(
          color: PrismColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PrismColors.border, width: 0.6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                rule.domainPattern,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PrismColors.ink1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: PrismColors.pp50,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                rule.tier,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: PrismColors.pp700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
