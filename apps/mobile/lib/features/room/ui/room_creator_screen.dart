import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/safe_route.dart';
import '../../../app/theme.dart';
import '../../../core/api_error.dart';
import '../../../features/category/data/category_repository.dart';
import '../../event_card/data/event_card_dto.dart';
import '../../event_card/ui/event_picker_modal.dart';
import '../../reference/data/reference_dto.dart';
import '../../reference/ui/reference_form_modal.dart';
import '../../topic_hub/data/topic_hub_repository.dart';
import '../../../widgets/event_card_widget.dart';
import '../../../widgets/reference_card_widget.dart';
import '../data/room_repository.dart';

const _kRoomTypes = <String, String>{
  'DISCUSSION': '토론',
  'EVENT_REACTION': '이벤트 반응',
  'REFERENCE': '레퍼런스',
};

class RoomCreatorScreen extends ConsumerStatefulWidget {
  const RoomCreatorScreen({
    super.key,
    required this.categorySlug,
    this.spaceSlug,
    this.returnTo,
  });
  final String categorySlug;

  /// Forwarded from TopicHubScreen so back-to-hub on cancel preserves
  /// the originating spaceSlug + returnTo. Submit success navigates
  /// forward to `/rooms/<slug>` so the round-trip context isn't needed
  /// there; only the back arrow uses it.
  final String? spaceSlug;
  final String? returnTo;

  @override
  ConsumerState<RoomCreatorScreen> createState() => _RoomCreatorScreenState();
}

class _RoomCreatorScreenState extends ConsumerState<RoomCreatorScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  String _roomType = 'DISCUSSION';
  EventCardDto? _pinnedEvent;
  ReferenceDto? _pinnedReference;
  bool _submitting = false;

  /// Back-to-Topic-Hub URL preserving the forwarded spaceSlug +
  /// returnTo. Mirrors the contribution composer's `_hubUrl()` so the
  /// round-trip lands in the same place a TopicHubScreen-only path
  /// would.
  String _hubUrl() {
    final params = <String, String>{};
    if (widget.spaceSlug != null && widget.spaceSlug!.isNotEmpty) {
      params['spaceSlug'] = widget.spaceSlug!;
    }
    if (isSafeInternalRoute(widget.returnTo)) {
      params['returnTo'] = widget.returnTo!;
    }
    final path = '/categories/${widget.categorySlug}';
    if (params.isEmpty) return path;
    return Uri(path: path, queryParameters: params).toString();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final room = await ref.read(roomRepositoryProvider).create(
            widget.categorySlug,
            CreateRoomRequest(
              name: _name.text.trim(),
              description: _description.text.trim(),
              roomType: _roomType,
              pinnedEventCardId: _pinnedEvent?.id,
              pinnedReferenceId: _pinnedReference?.id,
            ),
          );
      // Invalidate so Topic Hub picks up the new room on the way back.
      ref.invalidate(topicHubProvider(widget.categorySlug));
      ref.invalidate(categoryListProvider('participant'));
      if (mounted) context.go('/rooms/${room.slug}');
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('방 생성 실패: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('방 만들기'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(_hubUrl()),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('만들기'),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('카테고리: ${widget.categorySlug}',
                style: const TextStyle(color: PrismColors.muted)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '방 이름',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? '방 이름을 입력해 주세요.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: '설명',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Text('유형', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _kRoomTypes.entries.map((e) {
                final selected = _roomType == e.key;
                return ChoiceChip(
                  label: Text(e.value),
                  selected: selected,
                  onSelected: (_) => setState(() => _roomType = e.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('대표 자료 (선택)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showEventPickerModal(context);
                      if (selected != null) {
                        setState(() => _pinnedEvent = selected);
                      }
                    },
                    icon: const Icon(Icons.event),
                    label: Text(_pinnedEvent == null ? '이벤트 추가' : '이벤트 변경'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showReferenceFormModal(context);
                      if (selected != null) {
                        setState(() => _pinnedReference = selected);
                      }
                    },
                    icon: const Icon(Icons.link),
                    label: Text(
                        _pinnedReference == null ? '레퍼런스 추가' : '레퍼런스 변경'),
                  ),
                ),
              ],
            ),
            if (_pinnedEvent != null) ...[
              const SizedBox(height: 10),
              EventCardWidget(card: _pinnedEvent!, compact: true),
            ],
            if (_pinnedReference != null) ...[
              const SizedBox(height: 10),
              ReferenceCardWidget(reference: _pinnedReference!, compact: true),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
