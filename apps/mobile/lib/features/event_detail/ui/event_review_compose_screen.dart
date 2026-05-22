import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../data/event_detail_repository.dart';
import '../data/review_repository.dart';

class EventReviewComposeScreen extends ConsumerStatefulWidget {
  const EventReviewComposeScreen({super.key, required this.eventCardId});

  final String eventCardId;

  @override
  ConsumerState<EventReviewComposeScreen> createState() =>
      _EventReviewComposeScreenState();
}

class _EventReviewComposeScreenState
    extends ConsumerState<EventReviewComposeScreen> {
  int _rating = 5;
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final body = _ctrl.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('후기 내용을 입력해주세요')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(reviewRepositoryProvider).createOrUpdate(
            widget.eventCardId,
            rating: _rating,
            body: body,
          );
      ref.invalidate(eventDetailProvider(widget.eventCardId));
      if (mounted) context.pop();
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('후기 등록 실패: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('후기 쓰기')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PrismSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '이벤트는 어떠셨나요?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: PrismColors.ink1,
                ),
              ),
              const SizedBox(height: PrismSpacing.md),
              Row(
                children: List.generate(5, (i) {
                  final filled = i < _rating;
                  return IconButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _rating = i + 1),
                    icon: Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: filled ? PrismColors.warningFg : PrismColors.muted,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: PrismSpacing.lg),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  enabled: !_busy,
                  maxLines: null,
                  expands: true,
                  maxLength: 2000,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: '인상 깊었던 점이나 다음에 참여할 다른 사람들에게 도움이 될 정보를 남겨주세요.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: PrismSpacing.md),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: PrismColors.pp600,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('등록'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
