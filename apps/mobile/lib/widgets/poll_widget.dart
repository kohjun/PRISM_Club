import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/design_tokens.dart';
import '../core/api_error.dart';
import '../features/post/data/poll_repository.dart';
import '../features/post/data/post_dto.dart';

/// P6.5 poll renderer. Used inline on post cards + on the post detail
/// screen. Reads `poll` from the parent post DTO; mutates local state
/// via [PollRepository.vote] and re-emits the updated DTO so the
/// parent screen can update its post object.
class PollWidget extends ConsumerStatefulWidget {
  const PollWidget({
    super.key,
    required this.poll,
    required this.onVoted,
  });

  final PollDto poll;
  final ValueChanged<PollDto> onVoted;

  @override
  ConsumerState<PollWidget> createState() => _PollWidgetState();
}

class _PollWidgetState extends ConsumerState<PollWidget> {
  bool _busy = false;
  late PollDto _poll;

  @override
  void initState() {
    super.initState();
    _poll = widget.poll;
  }

  @override
  void didUpdateWidget(covariant PollWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poll.id != widget.poll.id ||
        oldWidget.poll.totalVotes != widget.poll.totalVotes) {
      _poll = widget.poll;
    }
  }

  Future<void> _vote(String optionId) async {
    if (_busy || !_poll.isOpen) return;
    setState(() => _busy = true);
    try {
      final updated =
          await ref.read(pollRepositoryProvider).vote(_poll.id, optionId);
      if (!mounted) return;
      setState(() => _poll = updated);
      widget.onVoted(updated);
    } on ApiError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('투표 실패: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = _poll;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.cardPad,
        vertical: PrismSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: PrismColors.bgTint,
        borderRadius: BorderRadius.circular(PrismRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            poll.question,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: PrismColors.ink1,
            ),
          ),
          const SizedBox(height: PrismSpacing.sm),
          for (final opt in poll.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _OptionBar(
                option: opt,
                totalVotes: poll.totalVotes,
                voted: poll.hasVotedFor(opt.id),
                enabled: poll.isOpen && !_busy,
                onTap: () => _vote(opt.id),
              ),
            ),
          const SizedBox(height: 4),
          _Footer(poll: poll),
        ],
      ),
    );
  }
}

class _OptionBar extends StatelessWidget {
  const _OptionBar({
    required this.option,
    required this.totalVotes,
    required this.voted,
    required this.enabled,
    required this.onTap,
  });

  final PollOptionDto option;
  final int totalVotes;
  final bool voted;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = totalVotes == 0 ? 0.0 : (option.voteCount / totalVotes);
    final pctLabel = totalVotes == 0 ? '0%' : '${(pct * 100).round()}%';

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(PrismRadius.md),
      child: Stack(
        children: [
          // Filled progress bar behind the label.
          Positioned.fill(
            child: FractionallySizedBox(
              widthFactor: pct.clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: voted ? PrismColors.pp100 : PrismColors.bgSoft,
                  borderRadius: BorderRadius.circular(PrismRadius.md),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: PrismSpacing.md,
              vertical: 10,
            ),
            constraints: const BoxConstraints(minHeight: 36),
            child: Row(
              children: [
                if (voted) ...[
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: PrismColors.pp700,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: voted ? FontWeight.w700 : FontWeight.w500,
                      color: PrismColors.ink1,
                    ),
                  ),
                ),
                Text(
                  pctLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PrismColors.ink3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.poll});
  final PollDto poll;

  String _formatExpiry(DateTime? at) {
    if (at == null) return '마감 없음';
    final diff = at.difference(DateTime.now());
    if (diff.isNegative) return '마감됨';
    if (diff.inHours < 1) return '약 ${diff.inMinutes}분 남음';
    if (diff.inDays < 1) return '약 ${diff.inHours}시간 남음';
    return '약 ${diff.inDays}일 남음';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(
        fontSize: 11.5,
        color: PrismColors.ink4,
      ),
      child: Row(
        children: [
          Text('총 ${poll.totalVotes}표'),
          const SizedBox(width: 8),
          Container(width: 3, height: 3,
              decoration: const BoxDecoration(
                color: PrismColors.ink4,
                shape: BoxShape.circle,
              )),
          const SizedBox(width: 8),
          Text(_formatExpiry(poll.expiresAt)),
          if (poll.allowMultiple) ...[
            const SizedBox(width: 8),
            Container(width: 3, height: 3,
                decoration: const BoxDecoration(
                  color: PrismColors.ink4,
                  shape: BoxShape.circle,
                )),
            const SizedBox(width: 8),
            const Text('복수 선택'),
          ],
        ],
      ),
    );
  }
}
