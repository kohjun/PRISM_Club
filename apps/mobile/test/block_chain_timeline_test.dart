import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/knowledge/data/chain_dto.dart';
import 'package:mobile/features/knowledge/data/chain_repository.dart';
import 'package:mobile/features/knowledge/ui/block_chain_timeline_screen.dart';

ChainDto _chain({List<ChainEntryDto>? items}) => ChainDto(
      blockId: 'block-1',
      items: items ??
          const [
            ChainEntryDto(
              userId: 'u-seed',
              nickname: 'seed_user',
              roleInChain: 'SEED',
              actedAt: '2026-04-01T09:00:00Z',
              revisionVersion: 1,
              contributionId: null,
            ),
            ChainEntryDto(
              userId: 'u-coral',
              nickname: 'coral',
              roleInChain: 'CONTRIBUTION',
              actedAt: '2026-05-15T09:00:00Z',
              revisionVersion: 2,
              contributionId: 'contrib-1',
            ),
            ChainEntryDto(
              userId: null,
              nickname: null,
              roleInChain: 'ADMIN',
              actedAt: '2026-05-20T09:00:00Z',
              revisionVersion: 3,
              contributionId: null,
            ),
          ],
    );

Widget _wrap(Widget child, {required ChainDto data}) => ProviderScope(
      overrides: [
        blockChainProvider('block-1').overrideWith((_) async => data),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('renders one tile per chain entry with role label + version',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const BlockChainTimelineScreen(blockId: 'block-1'),
      data: _chain(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('기여자 체인'), findsOneWidget);
    expect(find.text('seed_user'), findsOneWidget);
    expect(find.text('coral'), findsOneWidget);
    expect(find.text('(삭제된 사용자)'), findsOneWidget);

    expect(find.text('초기 등록'), findsOneWidget);
    expect(find.text('기여'), findsOneWidget);
    expect(find.text('관리자'), findsOneWidget);

    expect(find.textContaining('v1'), findsOneWidget);
    expect(find.textContaining('v2'), findsOneWidget);
    expect(find.textContaining('v3'), findsOneWidget);
  });

  testWidgets('empty chain shows the empty-state copy', (tester) async {
    await tester.pumpWidget(_wrap(
      const BlockChainTimelineScreen(blockId: 'block-1'),
      data: _chain(items: const []),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 이 블록에 남은 기여 기록이 없어요'),
        findsOneWidget);
  });
}
