import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../data/recruitment_repository.dart';

/// Bottom sheet for submitting a recruitment application (P3.6).
/// Returns `true` from `showModalBottomSheet` when the user successfully
/// applied so the caller can refresh the post detail.
class RecruitmentApplySheet extends ConsumerStatefulWidget {
  const RecruitmentApplySheet({super.key, required this.postId});

  final String postId;

  static Future<bool?> show(
    BuildContext context, {
    required String postId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PrismColors.bg,
      builder: (_) => RecruitmentApplySheet(postId: postId),
    );
  }

  @override
  ConsumerState<RecruitmentApplySheet> createState() =>
      _RecruitmentApplySheetState();
}

class _RecruitmentApplySheetState
    extends ConsumerState<RecruitmentApplySheet> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(recruitmentRepositoryProvider).apply(
            widget.postId,
            message: _ctrl.text.trim().isEmpty ? null : _ctrl.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('지원 실패: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        PrismSpacing.xl,
        PrismSpacing.xl,
        PrismSpacing.xl,
        PrismSpacing.xl + bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '지원하기',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: PrismColors.ink1,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '간단한 자기소개나 합류 가능 시점을 남겨두면 합격 가능성이 높아요.',
            style: TextStyle(fontSize: 13, color: PrismColors.muted),
          ),
          const SizedBox(height: PrismSpacing.lg),
          TextField(
            controller: _ctrl,
            enabled: !_busy,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              hintText: '메시지 (선택)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: PrismSpacing.lg),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PrismColors.pp600,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('지원하기'),
          ),
        ],
      ),
    );
  }
}
