import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/user_profile/data/curator_portfolio_dto.dart';
import 'package:mobile/features/user_profile/data/curator_portfolio_repository.dart';
import 'package:mobile/features/user_profile/ui/curator_portfolio_screen.dart';

CuratorPortfolioDto _full() => const CuratorPortfolioDto(
      userId: 'u-coral',
      isCurator: true,
      reputation: CuratorReputationDto(
        weightedScore: 12.5,
        approvedCount: 5,
        rejectedCount: 1,
        needsChangesCount: 2,
        withdrawnCount: 0,
      ),
      resolvedContributions: [
        ResolvedContributionDto(
          id: 'c-1',
          title: 'FAQ',
          blockType: 'FAQ',
          categorySlug: 'love-content',
          resolvedAt: '2026-05-15T03:00:00.000Z',
        ),
      ],
      sourceRules: [
        SourceRuleDto(
          id: 'r-1',
          domainPattern: 'tving.com',
          tier: 'OFFICIAL',
          note: null,
          createdAt: '2026-05-01T00:00:00.000Z',
        ),
      ],
    );

Widget _wrap(CuratorPortfolioDto data) => ProviderScope(
      overrides: [
        curatorPortfolioProvider('u-coral').overrideWith((_) async => data),
      ],
      child: const MaterialApp(
        home: CuratorPortfolioScreen(userId: 'u-coral'),
      ),
    );

void main() {
  testWidgets('renders reputation + contribution + source rule sections',
      (tester) async {
    await tester.pumpWidget(_wrap(_full()));
    await tester.pumpAndSettle();

    expect(find.text('큐레이터 포트폴리오'), findsOneWidget); // AppBar
    expect(find.text('12.5'), findsOneWidget); // weighted score
    expect(find.text('검수한 기여'), findsOneWidget);
    expect(find.byKey(const Key('portfolio-contribution-c-1')), findsOneWidget);
    expect(find.text('FAQ'), findsOneWidget);
    expect(find.text('도입한 출처 규칙'), findsOneWidget);
    expect(find.text('tving.com'), findsOneWidget);
    expect(find.text('OFFICIAL'), findsOneWidget);
  });

  testWidgets('empty portfolio shows the empty-state copy', (tester) async {
    await tester.pumpWidget(_wrap(const CuratorPortfolioDto(
      userId: 'u-coral',
      isCurator: false,
      reputation: null,
      resolvedContributions: [],
      sourceRules: [],
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 모인 큐레이션 기록이 없어요'), findsOneWidget);
  });

  testWidgets('contribution section hidden when no resolved contributions',
      (tester) async {
    await tester.pumpWidget(_wrap(const CuratorPortfolioDto(
      userId: 'u-coral',
      isCurator: true,
      reputation: CuratorReputationDto(
        weightedScore: 3,
        approvedCount: 1,
        rejectedCount: 0,
        needsChangesCount: 0,
        withdrawnCount: 0,
      ),
      resolvedContributions: [],
      sourceRules: [],
    )));
    await tester.pumpAndSettle();
    expect(find.text('3.0'), findsOneWidget); // reputation still shows
    expect(find.text('검수한 기여'), findsNothing);
    expect(find.text('도입한 출처 규칙'), findsNothing);
  });
}
