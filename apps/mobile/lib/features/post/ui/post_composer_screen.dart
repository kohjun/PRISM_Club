import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../core/api_error.dart';
import '../../../widgets/event_card_widget.dart';
import '../../../widgets/media_image.dart';
import '../../../widgets/mention_autocomplete.dart';
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
    this.quotedPostId,
    this.quotedPreview,
  });
  final String roomSlug;

  /// When non-null, the composer fetches this EventCard and pre-attaches it.
  /// The user can still remove it via the close button before submitting
  /// (M5 acceptance criterion #3).
  final String? initialEventCardId;

  /// P4.2: when set, the composer sends `quoted_post_id` to the server so
  /// the new post stores a `post_quotes` row. `quotedPreview` is shown
  /// inline above the body field so the user can see what they're
  /// quoting (and remove it).
  final String? quotedPostId;
  final String? quotedPreview;

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
  String? _quotedPostId;
  String? _quotedPreview;

  @override
  void initState() {
    super.initState();
    final id = widget.initialEventCardId;
    if (id != null && id.isNotEmpty) {
      _prefetchInitialEvent(id);
    }
    _quotedPostId = widget.quotedPostId;
    _quotedPreview = widget.quotedPreview;
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
            quotedPostId: _quotedPostId,
          );
      ref.invalidate(timelineProvider(widget.roomSlug));
      if (mounted) {
        context.canPop()
            ? context.pop()
            : context.go('/rooms/${widget.roomSlug}');
      }
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
      appBar: _ComposerAppBar(
        title: '글쓰기',
        submitting: _submitting,
        onClose: () => context.canPop()
            ? context.pop()
            : context.go('/rooms/${widget.roomSlug}'),
        onSubmit: _submit,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          PrismSpacing.xl,
          PrismSpacing.lg,
          PrismSpacing.xl,
          PrismSpacing.xl4,
        ),
        children: [
          _ComposerCaption(text: '방: ${widget.roomSlug}'),
          const SizedBox(height: PrismSpacing.md),
          if (_quotedPostId != null && _quotedPreview != null) ...[
            _QuoteChip(
              preview: _quotedPreview!,
              onRemove: () => setState(() {
                _quotedPostId = null;
                _quotedPreview = null;
              }),
            ),
            const SizedBox(height: PrismSpacing.md),
          ],
          MentionAutocomplete(
            controller: _body,
            child: TextField(
              controller: _body,
              maxLines: 8,
              minLines: 5,
              decoration: const InputDecoration(
                hintText: '무슨 이야기를 나눌까요?  (@닉네임 으로 누군가를 언급할 수 있어요)',
              ),
            ),
          ),
          const SizedBox(height: PrismSpacing.lg),
          const _ComposerSectionHeader(text: '첨부'),
          const SizedBox(height: PrismSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AttachActionButton(
                onPressed: _pickEvent,
                icon: Icons.event_outlined,
                label: '이벤트',
              ),
              _AttachActionButton(
                onPressed: _pickReference,
                icon: Icons.link,
                label: '레퍼런스',
              ),
              _AttachActionButton(
                onPressed: _uploadingImage ? null : _pickImage,
                icon: Icons.image_outlined,
                label: '이미지',
                busy: _uploadingImage,
              ),
            ],
          ),
          if (_attachedImages.isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.lg),
            const _ComposerSectionHeader(text: '첨부된 이미지'),
            const SizedBox(height: PrismSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _attachedImages
                  .map((m) => ClipRRect(
                        borderRadius: BorderRadius.circular(PrismRadius.md),
                        child: Stack(
                          children: [
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: MediaImage(asset: m, fit: BoxFit.cover),
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: _RemoveAttachmentButton(
                                onTap: () => setState(
                                    () => _attachedImages.remove(m)),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (_prefetchingEvent) ...[
            const SizedBox(height: PrismSpacing.lg),
            const _ComposerInlineLoading(text: '이벤트 카드 불러오는 중…'),
          ],
          if (_attachedEvents.isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.lg),
            const _ComposerSectionHeader(text: '첨부된 이벤트'),
            const SizedBox(height: PrismSpacing.sm),
            for (var i = 0; i < _attachedEvents.length; i++) ...[
              _AttachmentTile(
                child: EventCardWidget(
                    card: _attachedEvents[i], compact: true),
                onRemove: () =>
                    setState(() => _attachedEvents.removeAt(i)),
              ),
              const SizedBox(height: 6),
            ],
          ],
          if (_attachedRefs.isNotEmpty) ...[
            const SizedBox(height: PrismSpacing.lg),
            const _ComposerSectionHeader(text: '첨부된 레퍼런스'),
            const SizedBox(height: PrismSpacing.sm),
            for (var i = 0; i < _attachedRefs.length; i++) ...[
              _AttachmentTile(
                child: ReferenceCardWidget(
                    reference: _attachedRefs[i], compact: true),
                onRemove: () => setState(() => _attachedRefs.removeAt(i)),
              ),
              const SizedBox(height: 6),
            ],
          ],
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 24),
        ],
      ),
    );
  }
}

class _AttachActionButton extends StatelessWidget {
  const _AttachActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.busy = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: PrismSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PrismRadius.pill),
        ),
        side: const BorderSide(color: PrismColors.line2),
        foregroundColor: PrismColors.ink2,
      ),
    );
  }
}

class _RemoveAttachmentButton extends StatelessWidget {
  const _RemoveAttachmentButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '첨부 제거',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Align(
            alignment: Alignment.topRight,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xCC0B0B0F),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
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
          top: 4,
          right: 4,
          child: _RemoveAttachmentButton(onTap: onRemove),
        ),
      ],
    );
  }
}

class _ComposerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ComposerAppBar({
    required this.title,
    required this.submitting,
    required this.onClose,
    required this.onSubmit,
  });

  final String title;
  final bool submitting;
  final VoidCallback onClose;
  final VoidCallback onSubmit;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: '닫기',
        onPressed: onClose,
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PrismSpacing.sm,
            vertical: 8,
          ),
          child: FilledButton(
            onPressed: submitting ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: PrismColors.pp600,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PrismRadius.pill),
              ),
            ),
            child: submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '게시',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ComposerSectionHeader extends StatelessWidget {
  const _ComposerSectionHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: PrismColors.ink2,
      ),
    );
  }
}

class _ComposerCaption extends StatelessWidget {
  const _ComposerCaption({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: PrismColors.ink3,
        fontSize: 12.5,
      ),
    );
  }
}

class _QuoteChip extends StatelessWidget {
  const _QuoteChip({required this.preview, required this.onRemove});
  final String preview;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.cardPad,
        vertical: PrismSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: PrismColors.bgTint,
        borderRadius: BorderRadius.circular(PrismRadius.md),
        border: Border(
          left: BorderSide(color: PrismColors.pp400, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '인용 중',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: PrismColors.ink3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: PrismColors.ink2,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '인용 해제',
            icon: const Icon(Icons.close, size: 18, color: PrismColors.ink3),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          ),
        ],
      ),
    );
  }
}

class _ComposerInlineLoading extends StatelessWidget {
  const _ComposerInlineLoading({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: PrismColors.pp600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: PrismColors.ink3,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
