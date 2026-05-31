import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
import '../../dm/ui/dm_actions.dart';
import '../data/recruitment_dto.dart';
import '../data/recruitment_repository.dart';

class RecruitmentApplicantsScreen extends ConsumerWidget {
  const RecruitmentApplicantsScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(postApplicationsProvider(postId));
    return Scaffold(
      appBar: AppBar(title: const Text('지원자 보기')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '지원자를 불러오지 못했어요.',
          onRetry: () => ref.invalidate(postApplicationsProvider(postId)),
        ),
        data: (list) => RefreshIndicator(
          color: PrismColors.pp600,
          onRefresh: () async =>
              ref.invalidate(postApplicationsProvider(postId)),
          child: ListView(
            padding: const EdgeInsets.all(PrismSpacing.xl),
            children: [
              _CapacityHeader(list: list),
              const SizedBox(height: PrismSpacing.lg),
              if (list.items.isEmpty)
                const EmptyView(message: '아직 지원자가 없어요.')
              else
                ...list.items.map(
                  (a) => _ApplicantTile(postId: postId, app: a),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapacityHeader extends StatelessWidget {
  const _CapacityHeader({required this.list});
  final ApplicationsListDto list;

  @override
  Widget build(BuildContext context) {
    final capStr =
        list.capacity != null ? '${list.acceptedCount}/${list.capacity}' : '${list.acceptedCount}';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: PrismColors.pp50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.group_outlined,
            color: PrismColors.pp700,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            '수락 $capStr · 상태 ${list.recruitmentStatus}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: PrismColors.pp700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicantTile extends ConsumerStatefulWidget {
  const _ApplicantTile({required this.postId, required this.app});
  final String postId;
  final RecruitmentApplicationDto app;

  @override
  ConsumerState<_ApplicantTile> createState() => _ApplicantTileState();
}

class _ApplicantTileState extends ConsumerState<_ApplicantTile> {
  bool _busy = false;

  Future<void> _decide(String decision) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(recruitmentRepositoryProvider)
          .decide(widget.app.id, decision);
      ref.invalidate(postApplicationsProvider(widget.postId));
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리 실패: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.app;
    final isPending = a.status == 'PENDING';
    return Container(
      margin: const EdgeInsets.only(bottom: PrismSpacing.md),
      padding: const EdgeInsets.all(PrismSpacing.lg),
      decoration: BoxDecoration(
        color: PrismColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PrismColors.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                a.applicantNickname ?? '익명',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PrismColors.ink1,
                ),
              ),
              const Spacer(),
              _StatusPill(status: a.status),
            ],
          ),
          if (a.message != null && a.message!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              a.message!,
              style: const TextStyle(
                fontSize: 13,
                color: PrismColors.ink2,
                height: 1.5,
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: PrismSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _decide('REJECT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PrismColors.dangerFg,
                    ),
                    child: const Text('거절'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _decide('ACCEPT'),
                    style: FilledButton.styleFrom(
                      backgroundColor: PrismColors.pp600,
                    ),
                    child: const Text('수락'),
                  ),
                ),
              ],
            ),
          ],
          if (a.status == 'PENDING' || a.status == 'ACCEPTED') ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => openScopedDm(
                  context,
                  ref,
                  scope: 'RECRUITMENT',
                  refId: widget.postId,
                  counterpartId: a.applicantId,
                  peerName: a.applicantNickname,
                ),
                icon: const Icon(Icons.mail_outline, size: 16),
                label: const Text('메시지'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
      'ACCEPTED' => ('수락', PrismColors.successFg, PrismColors.successBg),
      'REJECTED' => ('거절', PrismColors.dangerFg, PrismColors.dangerBg),
      'WITHDRAWN' => ('취소', PrismColors.muted, PrismColors.bgTint),
      _ => ('대기', PrismColors.warningFg, PrismColors.warningBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
