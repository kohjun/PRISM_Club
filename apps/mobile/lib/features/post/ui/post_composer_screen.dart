import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_error.dart';
import '../../../widgets/event_card_widget.dart';
import '../../../widgets/media_image.dart';
import '../../../widgets/reference_card_widget.dart';
import '../../event_card/data/event_card_dto.dart';
import '../../event_card/ui/event_picker_modal.dart';
import '../../event_detail/data/event_detail_repository.dart';
import '../../media/data/media_dto.dart';
import '../../media/data/media_repository.dart';
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
  final _attachedImages = <MediaAssetDto>[];
  bool _submitting = false;
  bool _prefetchingEvent = false;
  bool _uploadingImage = false;

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

  Future<void> _pickImage() async {
    if (_attachedImages.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지는 최대 4장까지 첨부할 수 있어요.')),
      );
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = picked?.files.first;
    if (file == null || file.bytes == null) return;
    setState(() => _uploadingImage = true);
    try {
      final mime = _guessMime(file.name);
      final asset = await ref.read(mediaRepositoryProvider).uploadImage(
            bytes: file.bytes!,
            filename: file.name,
            contentType: mime,
          );
      if (mounted) {
        setState(() => _attachedImages.add(asset));
      }
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 업로드 실패: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  String _guessMime(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
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
        for (final m in _attachedImages)
          CreatePostAttachment(attachmentType: 'IMAGE', targetId: m.id),
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
              OutlinedButton.icon(
                onPressed: _uploadingImage ? null : _pickImage,
                icon: _uploadingImage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined),
                label: const Text('이미지'),
              ),
            ],
          ),
          if (_attachedImages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _attachedImages
                  .map((m) => Stack(
                        children: [
                          SizedBox(
                              width: 100,
                              height: 100,
                              child: MediaImage(asset: m, fit: BoxFit.cover)),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.cancel,
                                  size: 20, color: Colors.black54),
                              onPressed: () =>
                                  setState(() => _attachedImages.remove(m)),
                            ),
                          ),
                        ],
                      ))
                  .toList(),
            ),
          ],
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
