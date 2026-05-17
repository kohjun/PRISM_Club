import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('신고하기',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 4),
          Text(
            '${widget.targetType.toLowerCase()} 신고',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ..._reasons.map((r) => RadioListTile<String>(
                title: Text(r),
                value: r,
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v ?? _reason),
                dense: true,
                contentPadding: EdgeInsets.zero,
              )),
          const SizedBox(height: 8),
          TextField(
            controller: _detailsCtrl,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '추가 설명 (선택)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? '신고 중...' : '신고'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
