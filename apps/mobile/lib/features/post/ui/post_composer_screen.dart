import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_error.dart';
import '../../../widgets/event_card_widget.dart';
import '../../../widgets/reference_card_widget.dart';
import '../../event_card/data/event_card_dto.dart';
import '../../event_card/ui/event_picker_modal.dart';
import '../../event_detail/data/event_detail_repository.dart';
import '../../reference/data/reference_dto.dart';
import '../../reference/ui/reference_form_modal.dart';
import '../data/post_repository.dart';

class PostComposerScreen extends ConsumerStatefulWidget {
  const PostComposerScreen({
    super.key,
    required this.roomSlug,
    this.initialEventCardId,
  });
  final String roomSlug;

  /// When non-null, the composer fetches this EventCard and pre-attaches it.
  /// The user can still remove it via the close button before submitting
  /// (M5 acceptance criterion #3).
  final String? initialEventCardId;

  @override
  ConsumerState<PostComposerScreen> createState() => _PostComposerScreenState();
}

class _PostComposerScreenState extends ConsumerState<PostComposerScreen> {
  final _body = TextEditingController();
  final _attachedEvents = <EventCardDto>[];
  final _attachedRefs = <ReferenceDto>[];
  bool _submitting = false;
  bool _prefetchingEvent = false;

  @override
  void initState() {
    super.initState();
    final id = widget.initialEventCardId;
    if (id != null && id.isNotEmpty) {
      _prefetchInitialEvent(id);
    }
  }

  Future<void> _prefetchInitialEvent(String id) async {
    setState(() => _prefetchingEvent = true);
    try {
      final card =
          await ref.read(eventDetailRepositoryProvider).getEventCardById(id);
      if (mounted) {
        setState(() {
          _attachedEvents.add(card);
        });
      }
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이벤트 카드를 불러오지 못했어요: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _prefetchingEvent = false);
    }
  }

  Future<void> _pickEvent() async {
    final selected = await showEventPickerModal(context);
    if (selected != null && mounted) {
      setState(() => _attachedEvents.add(selected));
    }
  }

  Future<void> _pickReference() async {
    final selected = await showReferenceFormModal(context);
    if (selected != null && mounted) {
      setState(() => _attachedRefs.add(selected));
    }
  }

  Future<void> _submit() async {
    final text = _body.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해 주세요.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final attachments = <CreatePostAttachment>[
        for (final e in _attachedEvents)
          CreatePostAttachment(attachmentType: 'EVENT_CARD', targetId: e.id),
        for (final r in _attachedRefs)
          CreatePostAttachment(attachmentType: 'REFERENCE', targetId: r.id),
      ];
      await ref.read(postRepositoryProvider).create(
            widget.roomSlug,
            body: text,
            attachments: attachments,
          );
      ref.invalidate(timelineProvider(widget.roomSlug));
      if (mounted) context.go('/rooms/${widget.roomSlug}');
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('글 작성 실패: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('글쓰기'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/rooms/${widget.roomSlug}'),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('게시'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('방: ${widget.roomSlug}',
              style: const TextStyle(color: PrismColors.muted)),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            maxLines: 8,
            minLines: 5,
            decoration: const InputDecoration(
              hintText: '무슨 이야기를 나눌까요?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickEvent,
                icon: const Icon(Icons.event),
                label: const Text('이벤트'),
              ),
              OutlinedButton.icon(
                onPressed: _pickReference,
                icon: const Icon(Icons.link),
                label: const Text('레퍼런스'),
              ),
            ],
          ),
          if (_prefetchingEvent) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  '이벤트 카드 불러오는 중…',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: PrismColors.muted),
                ),
              ],
            ),
          ],
          if (_attachedEvents.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('첨부된 이벤트',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            for (var i = 0; i < _attachedEvents.length; i++) ...[
              _AttachmentTile(
                child: EventCardWidget(card: _attachedEvents[i], compact: true),
                onRemove: () =>
                    setState(() => _attachedEvents.removeAt(i)),
              ),
              const SizedBox(height: 6),
            ],
          ],
          if (_attachedRefs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('첨부된 레퍼런스',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            for (var i = 0; i < _attachedRefs.length; i++) ...[
              _AttachmentTile(
                child: ReferenceCardWidget(
                    reference: _attachedRefs[i], compact: true),
                onRemove: () => setState(() => _attachedRefs.removeAt(i)),
              ),
              const SizedBox(height: 6),
            ],
          ],
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.child, required this.onRemove});
  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
            tooltip: '제거',
          ),
        ),
      ],
    );
  }
}
