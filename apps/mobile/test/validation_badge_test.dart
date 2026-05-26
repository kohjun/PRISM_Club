import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/knowledge/data/validation_dto.dart';
import 'package:mobile/features/knowledge/data/validation_repository.dart';
import 'package:mobile/features/knowledge/ui/widgets/validation_badge.dart';

ValidationDto _v(String label, {double score = 0}) => ValidationDto(
      blockId: 'block-1',
      score: score,
      label: label,
      signals: const ValidationSignalsDto(
        revisions: 1,
        approvals: 2,
        avgReputation: 3.2,
        ageDays: 5,
      ),
      computedAt: '2026-05-26T12:00:00Z',
    );

Widget _wrap(Widget child, {required ValidationDto data}) => ProviderScope(
      overrides: [
        blockValidationProvider('block-1').overrideWith((_) async => data),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('renders the label and score wrapped in the badge chip',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const ValidationBadge(blockId: 'block-1'),
      data: _v('충분히 검증됨', score: 18.3),
    ));
    await tester.pump();

    expect(find.text('충분히 검증됨'), findsOneWidget);
    expect(find.byKey(const Key('validation-badge-block-1')), findsOneWidget);
  });

  testWidgets('tap opens the signals sheet with the four signal rows',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const ValidationBadge(blockId: 'block-1'),
      data: _v('검증 진행 중', score: 8.4),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const Key('validation-badge-block-1')));
    await tester.pumpAndSettle();

    expect(find.text('검증 강도 · 검증 진행 중'), findsOneWidget);
    expect(find.text('개정 횟수'), findsOneWidget);
    expect(find.text('승인된 기여'), findsOneWidget);
    expect(find.text('평균 큐레이터 점수'), findsOneWidget);
    expect(find.text('등록 후 경과'), findsOneWidget);
    expect(find.text('1회'), findsOneWidget); // revisions
    expect(find.text('2건'), findsOneWidget); // approvals
    expect(find.byKey(const Key('open-chain-timeline')), findsOneWidget);
  });

  testWidgets('age >= 30 days collapses to "30일+" label',
      (tester) async {
    final dto = ValidationDto(
      blockId: 'block-1',
      score: 0,
      label: '검증 부족',
      signals: const ValidationSignalsDto(
        revisions: 0,
        approvals: 0,
        avgReputation: 0,
        ageDays: 30,
      ),
      computedAt: '2026-05-26T12:00:00Z',
    );
    await tester.pumpWidget(_wrap(
      const ValidationBadge(blockId: 'block-1'),
      data: dto,
    ));
    await tester.pump();
    await tester.tap(find.byKey(const Key('validation-badge-block-1')));
    await tester.pumpAndSettle();

    expect(find.text('30일+'), findsOneWidget);
  });
}
