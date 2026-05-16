import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/knowledge/data/contribution_dto.dart';
import 'package:mobile/widgets/contribution_card_widget.dart';

ContributionDto _c({
  required String title,
  required String status,
  String contributorNickname = '민서',
  String? targetBlockId = 'tb1',
  String? evidenceType,
  bool hasEvidence = false,
}) =>
    ContributionDto(
      id: 'c1',
      topicHubId: 'hub1',
      categorySlug: 'love-content',
      contributor: ContributionAuthor(id: 'u1', nickname: contributorNickname),
      targetBlockId: targetBlockId,
      proposedBlockType: 'FAQ',
      proposedTitle: title,
      status: status,
      evidenceType: evidenceType,
      hasEvidence: hasEvidence,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      resolvedAt: null,
    );

void main() {
  testWidgets('ContributionCardWidget renders title and PENDING status',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ContributionCardWidget(
          contribution: _c(title: '제안 제목', status: ContributionStatus.pending),
        ),
      ),
    ));
    expect(find.text('제안 제목'), findsOneWidget);
    expect(find.text('대기'), findsOneWidget);
    expect(find.text('민서'), findsOneWidget);
  });

  testWidgets('ContributionCardWidget shows "새 블록" tag when target is null',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ContributionCardWidget(
          contribution: _c(
              title: '새 체크리스트',
              status: ContributionStatus.pending,
              targetBlockId: null),
        ),
      ),
    ));
    expect(find.text('새 블록'), findsOneWidget);
  });

  testWidgets('ContributionCardWidget renders APPROVED label', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ContributionCardWidget(
          contribution:
              _c(title: '승인된 제안', status: ContributionStatus.approved),
        ),
      ),
    ));
    expect(find.text('승인됨'), findsOneWidget);
  });

  testWidgets('ContributionCardWidget shows evidence icon when has_evidence',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ContributionCardWidget(
          contribution: _c(
              title: '이벤트 근거',
              status: ContributionStatus.pending,
              evidenceType: 'EVENT_CARD',
              hasEvidence: true),
        ),
      ),
    ));
    expect(find.byIcon(Icons.event), findsOneWidget);
  });
}
