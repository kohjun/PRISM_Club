import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
import '../data/moderation_repository.dart';

class ModerationDetailScreen extends ConsumerStatefulWidget {
  const ModerationDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ModerationDetailScreen> createState() =>
      _ModerationDetailScreenState();
}

class _ModerationDetailScreenState
    extends ConsumerState<ModerationDetailScreen> {
  final _noteCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolve(String action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(moderationRepositoryProvider).resolve(
            widget.id,
            action: action,
            note: _noteCtrl.text.trim(),
          );
      ref.invalidate(moderationQueueProvider);
      ref.invalidate(reportDetailProvider(widget.id));
      if (mounted) context.go('/admin/reports');
    } catch (e) {
      setState(() {
        _error = e is ApiError ? e.message : e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(reportDetailProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: const Text('신고 상세')),
      body: detail.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '신고를 불러오지 못했어요.',
          onRetry: () => ref.invalidate(reportDetailProvider(widget.id)),
        ),
        data: (r) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _row('타겟', '${r.target.type} · ${r.target.preview}'),
            _row('상태', '${r.status}${r.resolution != null ? ' / ${r.resolution}' : ''}'),
            _row('신고자', r.reporterNickname ?? r.reporterId.substring(0, 8)),
            _row('사유', r.reason),
            if (r.details != null && r.details!.isNotEmpty)
              _row('추가 설명', r.details!),
            const Divider(),
            if (r.status == 'OPEN') ...[
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '처리 메모 (선택)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _busy ? null : () => _resolve('DISMISS'),
                    child: const Text('기각'),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : () => _resolve('HIDE'),
                    child: const Text('숨김 처리'),
                  ),
                  if (r.target.status == 'HIDDEN')
                    OutlinedButton(
                      onPressed: _busy ? null : () => _resolve('RESTORE'),
                      child: const Text('복원'),
                    ),
                ],
              ),
            ] else ...[
              Text('처리됨: ${r.resolution ?? '-'}'),
              if (r.resolverNote != null && r.resolverNote!.isNotEmpty)
                Text('메모: ${r.resolverNote}'),
            ],
            const SizedBox(height: 16),
            const Text('이력', style: TextStyle(fontWeight: FontWeight.w700)),
            if (r.actions.isEmpty) const Text('— 없음 —'),
            for (final a in r.actions)
              ListTile(
                dense: true,
                title: Text('${a.action} · ${a.actorNickname ?? ''}'),
                subtitle: Text(a.note ?? a.createdAt.toIso8601String()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 80,
                child: Text(k, style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(v)),
          ],
        ),
      );
}
