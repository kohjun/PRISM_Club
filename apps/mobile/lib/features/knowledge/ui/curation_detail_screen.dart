import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/event_card_widget.dart';
import '../../../widgets/reference_card_widget.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/status_pill.dart';
import '../../topic_hub/data/topic_hub_repository.dart';
import '../data/contribution_dto.dart';
import '../data/contribution_repository.dart';

class CurationDetailScreen extends ConsumerWidget {
  const CurationDetailScreen({super.key, required this.contributionId});
  final String contributionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(contributionDetailProvider(contributionId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('제안 검토'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/curate'),
        ),
      ),
      body: detail.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '제안을 불러오지 못했어요.',
          onRetry: () =>
              ref.invalidate(contributionDetailProvider(contributionId)),
        ),
        data: (d) => _Body(detail: d, contributionId: contributionId),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail, required this.contributionId});
  final ContributionDetailDto detail;
  final String contributionId;

  Future<void> _resolve(BuildContext context, WidgetRef ref, String decision) async {
    final note = await _askNote(context, decision);
    if (note == null) return; // cancelled

    try {
      await ref.read(contributionRepositoryProvider).resolve(
            contributionId,
            ResolveContributionRequest(
              decision: decision,
              note: note.isEmpty ? null : note,
            ),
          );
      // Refresh affected views.
      ref.invalidate(contributionDetailProvider(contributionId));
      ref.invalidate(adminContributionsProvider(ContributionStatus.pending));
      ref.invalidate(adminContributionsProvider(ContributionStatus.approved));
      ref.invalidate(adminContributionsProvider(ContributionStatus.rejected));
      ref.invalidate(adminContributionsProvider(ContributionStatus.needsChanges));
      ref.invalidate(topicHubProvider(detail.summary.categorySlug));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_resultMessage(decision))),
        );
        context.canPop() ? context.pop() : context.go('/curate');
      }
    } on ApiError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리 실패: ${e.message}')),
        );
      }
    }
  }

  Future<String?> _askNote(BuildContext context, String decision) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_decisionTitle(decision)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '메모 (선택)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _decisionTitle(String d) {
    switch (d) {
      case 'APPROVE':
        return '승인';
      case 'REJECT':
        return '거절';
      case 'REQUEST_CHANGES':
        return '보완 요청';
      default:
        return d;
    }
  }

  String _resultMessage(String d) {
    switch (d) {
      case 'APPROVE':
        return '승인되었습니다.';
      case 'REJECT':
        return '거절되었습니다.';
      case 'REQUEST_CHANGES':
        return '보완 요청을 전달했습니다.';
      default:
        return '처리되었습니다.';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = detail.summary;
    final isPending = summary.status == ContributionStatus.pending;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _StatusBadge(status: summary.status),
                  const SizedBox(width: 8),
                  Text(
                    '${summary.contributor.nickname} · ${_relativeTime(summary.createdAt)}',
                    style:
                        const TextStyle(fontSize: 12, color: PrismColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('제안 내용',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BlockTypeChip(blockType: summary.proposedBlockType),
                      const SizedBox(height: 6),
                      Text(summary.proposedTitle,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text(detail.proposedBody),
                    ],
                  ),
                ),
              ),
              if (detail.currentBlock != null) ...[
                const SizedBox(height: 16),
                Text('현재 블록',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  color: PrismColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BlockTypeChip(
                            blockType: detail.currentBlock!.blockType),
                        const SizedBox(height: 6),
                        Text(detail.currentBlock!.title,
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 6),
                        Text(detail.currentBlock!.body),
                      ],
                    ),
                  ),
                ),
              ],
              if (detail.evidenceEvent != null) ...[
                const SizedBox(height: 16),
                Text('근거 이벤트',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                EventCardWidget(card: detail.evidenceEvent!),
              ],
              if (detail.evidenceReference != null) ...[
                const SizedBox(height: 16),
                Text('근거 레퍼런스',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ReferenceCardWidget(reference: detail.evidenceReference!),
              ],
              if (detail.snapshot != null) ...[
                const SizedBox(height: 16),
                Text('승인 전 스냅샷',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  color: PrismColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(detail.snapshot!.title,
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 6),
                        Text(detail.snapshot!.body),
                      ],
                    ),
                  ),
                ),
              ],
              if (detail.curatorNote != null) ...[
                const SizedBox(height: 16),
                Text('큐레이터 메모',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(detail.curatorNote!),
                if (detail.resolverNickname != null) ...[
                  const SizedBox(height: 4),
                  Text('— ${detail.resolverNickname}',
                      style: const TextStyle(
                          fontSize: 12, color: PrismColors.muted)),
                ],
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
        if (isPending)
          Container(
            decoration: const BoxDecoration(
              color: PrismColors.bg,
              border: Border(
                top: BorderSide(color: PrismColors.line),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PrismSpacing.cardPad,
                  PrismSpacing.md,
                  PrismSpacing.cardPad,
                  PrismSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _resolve(context, ref, 'REQUEST_CHANGES'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          foregroundColor: PrismColors.warningFg,
                          side: const BorderSide(color: PrismColors.warningFg),
                        ),
                        child: const Text(
                          '보완 요청',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: PrismSpacing.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _resolve(context, ref, 'REJECT'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          foregroundColor: PrismColors.dangerFg,
                          side: const BorderSide(color: PrismColors.dangerFg),
                        ),
                        child: const Text(
                          '거절',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: PrismSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () => _resolve(context, ref, 'APPROVE'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: PrismColors.successFg,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          '승인',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ContributionStatus.pending:
        return StatusPill.purple('대기');
      case ContributionStatus.approved:
        return StatusPill.success('승인됨');
      case ContributionStatus.rejected:
        return StatusPill.danger('거절됨');
      case ContributionStatus.needsChanges:
        return StatusPill.warning('보완 요청');
      case ContributionStatus.withdrawn:
        return StatusPill.neutral('철회됨');
      default:
        return StatusPill.neutral(status);
    }
  }
}

class _BlockTypeChip extends StatelessWidget {
  const _BlockTypeChip({required this.blockType});
  final String blockType;

  static const _labels = <String, String>{
    'OVERVIEW': '개요',
    'POPULAR_FORMAT': '인기 포맷',
    'RECOMMENDED_PARTY_SIZE': '추천 인원',
    'MOOD_TIPS': '분위기 팁',
    'FAQ': 'FAQ',
    'CHECKLIST': '체크리스트',
    'WARNING': '주의사항',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: PrismColors.soft,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(_labels[blockType] ?? blockType,
          style: const TextStyle(fontSize: 11, color: PrismColors.primary)),
    );
  }
}
