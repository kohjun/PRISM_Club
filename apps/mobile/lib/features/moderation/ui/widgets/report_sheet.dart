import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design_tokens.dart';
import '../../../../core/api_error.dart';
import '../../data/moderation_repository.dart';

class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  final String targetType;
  final String targetId;

  static Future<bool?> show(
    BuildContext context, {
    required String targetType,
    required String targetId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PrismColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PrismRadius.xxl),
        ),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ReportSheet(targetType: targetType, targetId: targetId),
      ),
    );
  }

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  static const _reasons = ['스팸', '욕설/혐오', '허위정보', '저작권 침해', '기타'];
  String _reason = _reasons.first;
  final _detailsCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(moderationRepositoryProvider).createReport(
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: _reason,
            details: _detailsCtrl.text.trim(),
          );
      ref.invalidate(myReportsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e is ApiError ? e.message : e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PrismSpacing.xl,
          PrismSpacing.lg,
          PrismSpacing.xl,
          PrismSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '신고하기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: PrismColors.ink1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.targetType.toLowerCase()} 신고',
              style: const TextStyle(
                fontSize: 12,
                color: PrismColors.ink3,
              ),
            ),
            const SizedBox(height: PrismSpacing.lg),
            ..._reasons.map(
              (r) => RadioListTile<String>(
                title: Text(
                  r,
                  style: const TextStyle(
                    fontSize: 14,
                    color: PrismColors.ink1,
                  ),
                ),
                value: r,
                // ignore: deprecated_member_use
                groupValue: _reason,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _reason = v ?? _reason),
                activeColor: PrismColors.pp600,
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -1,
                ),
              ),
            ),
            const SizedBox(height: PrismSpacing.sm),
            TextField(
              controller: _detailsCtrl,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '추가 설명 (선택)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: PrismSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PrismSpacing.md,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: PrismColors.dangerBg,
                  borderRadius: BorderRadius.circular(PrismRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 14, color: PrismColors.dangerFg),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: PrismColors.dangerFg,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: PrismSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: PrismSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: PrismColors.dangerFg,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_submitting ? '신고 중...' : '신고'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
