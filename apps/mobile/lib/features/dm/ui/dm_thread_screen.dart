import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/state_views.dart';
import '../data/dm_dto.dart';
import '../data/dm_repository.dart';

/// P6.9 — `/dm/:channelId`. Message thread + composer. A CLOSED channel
/// is read-only (composer replaced by a banner). Long-pressing the
/// counterpart's message reports it.
class DmThreadScreen extends ConsumerStatefulWidget {
  const DmThreadScreen({super.key, required this.channelId, this.peerName});
  final String channelId;
  final String? peerName;

  @override
  ConsumerState<DmThreadScreen> createState() => _DmThreadScreenState();
}

class _DmThreadScreenState extends ConsumerState<DmThreadScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Mark the thread read on open (best-effort) and refresh the inbox
    // unread badge.
    Future.microtask(() async {
      await ref.read(dmRepositoryProvider).markRead(widget.channelId);
      ref.invalidate(dmChannelsProvider);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(dmRepositoryProvider).send(widget.channelId, text);
      _ctrl.clear();
      ref.invalidate(dmThreadProvider(widget.channelId));
      ref.invalidate(dmChannelsProvider);
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전송 실패: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _report(DmMessageDto m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('메시지 신고'),
        content: const Text('이 메시지를 신고할까요? 운영팀이 검토합니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('신고')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dmRepositoryProvider).reportMessage(m.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신고가 접수됐어요.')),
        );
      }
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('신고 실패: ${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(dmThreadProvider(widget.channelId));
    return Scaffold(
      appBar: AppBar(title: Text(widget.peerName ?? '메시지')),
      body: thread.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiError ? e.message : '대화를 불러오지 못했어요.',
          onRetry: () => ref.invalidate(dmThreadProvider(widget.channelId)),
        ),
        data: (page) {
          // API returns newest-first; render oldest-at-top.
          final msgs = page.items.reversed.toList(growable: false);
          return Column(
            children: [
              Expanded(
                child: msgs.isEmpty
                    ? const EmptyView(message: '첫 메시지를 보내보세요.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(PrismSpacing.md),
                        itemCount: msgs.length,
                        itemBuilder: (_, i) => _MessageBubble(
                          msg: msgs[i],
                          onReport: msgs[i].mine ? null : () => _report(msgs[i]),
                        ),
                      ),
              ),
              if (page.isClosed)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(PrismSpacing.md),
                  color: PrismColors.bgTint,
                  child: const SafeArea(
                    top: false,
                    child: Text(
                      '종료된 대화예요. 새 메시지를 보낼 수 없어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: PrismColors.ink4),
                    ),
                  ),
                )
              else
                _Composer(
                  controller: _ctrl,
                  sending: _sending,
                  onSubmit: _send,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.msg, this.onReport});
  final DmMessageDto msg;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final mine = msg.mine;
    final hidden = msg.isHidden;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.md,
        vertical: PrismSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: hidden
            ? PrismColors.bgTint
            : (mine ? PrismColors.pp600 : PrismColors.bgTint),
        borderRadius: BorderRadius.circular(PrismRadius.md),
      ),
      child: Text(
        hidden ? '숨김 처리된 메시지예요.' : msg.body,
        style: TextStyle(
          fontSize: 13.5,
          height: 1.4,
          fontStyle: hidden ? FontStyle.italic : FontStyle.normal,
          color: hidden
              ? PrismColors.ink4
              : (mine ? Colors.white : PrismColors.ink1),
        ),
      ),
    );
    return GestureDetector(
      onLongPress: onReport,
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: bubble,
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PrismColors.bg,
        border: Border(top: BorderSide(color: PrismColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        PrismSpacing.md,
        PrismSpacing.sm,
        PrismSpacing.md,
        MediaQuery.of(context).viewInsets.bottom + PrismSpacing.sm,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('dm-composer-field'),
                controller: controller,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '메시지 입력...',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: PrismSpacing.sm),
            FilledButton(
              key: const Key('dm-send-button'),
              onPressed: sending ? null : onSubmit,
              child: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('보내기'),
            ),
          ],
        ),
      ),
    );
  }
}
