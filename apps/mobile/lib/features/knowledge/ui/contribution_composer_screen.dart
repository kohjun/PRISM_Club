import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_error.dart';
import '../../../widgets/event_card_widget.dart';
import '../../../widgets/reference_card_widget.dart';
import '../../event_card/data/event_card_dto.dart';
import '../../event_card/ui/event_picker_modal.dart';
import '../../reference/data/reference_dto.dart';
import '../../reference/ui/reference_form_modal.dart';
import '../../topic_hub/data/topic_hub_dto.dart';
import '../../topic_hub/data/topic_hub_repository.dart';
import '../data/contribution_dto.dart';
import '../data/contribution_repository.dart';

const _kBlockTypes = <String, String>{
  'OVERVIEW': '개요',
  'POPULAR_FORMAT': '인기 포맷',
  'RECOMMENDED_PARTY_SIZE': '추천 인원',
  'MOOD_TIPS': '분위기 팁',
  'FAQ': 'FAQ',
  'CHECKLIST': '체크리스트',
  'WARNING': '주의사항',
};

/// Topic Hub "정보 개선 제안" composer.
///
/// Two modes:
/// - **edit existing**: pick a block; fields prefill with the current content.
/// - **propose new**: blank fields, block type chosen explicitly.
class ContributionComposerScreen extends ConsumerStatefulWidget {
  const ContributionComposerScreen({
    super.key,
    required this.categorySlug,
    this.initialTargetBlockId,
  });

  final String categorySlug;
  final String? initialTargetBlockId;

  @override
  ConsumerState<ContributionComposerScreen> createState() =>
      _ContributionComposerScreenState();
}

class _ContributionComposerScreenState
    extends ConsumerState<ContributionComposerScreen> {
  late bool _editExistingMode = widget.initialTargetBlockId != null;
  String? _selectedBlockId;
  String _blockType = 'FAQ';
  final _title = TextEditingController();
  final _body = TextEditingController();
  EventCardDto? _evidenceEvent;
  ReferenceDto? _evidenceReference;
  bool _submitting = false;
  bool _prefilledFromInitial = false;

  @override
  void initState() {
    super.initState();
    _selectedBlockId = widget.initialTargetBlockId;
  }

  void _prefillFromBlock(KnowledgeBlockDto block) {
    setState(() {
      _selectedBlockId = block.id;
      _blockType = block.blockType;
      _title.text = block.title;
      _body.text = block.body;
    });
  }

  void _switchToNewMode() {
    setState(() {
      _editExistingMode = false;
      _selectedBlockId = null;
      _blockType = 'FAQ';
      _title.clear();
      _body.clear();
    });
  }

  Future<void> _pickEvent() async {
    final card = await showEventPickerModal(context);
    if (card != null && mounted) {
      setState(() {
        _evidenceEvent = card;
        _evidenceReference = null;
      });
    }
  }

  Future<void> _pickReference() async {
    final r = await showReferenceFormModal(context);
    if (r != null && mounted) {
      setState(() {
        _evidenceReference = r;
        _evidenceEvent = null;
      });
    }
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 본문을 모두 입력해 주세요.')),
      );
      return;
    }
    if (_editExistingMode && _selectedBlockId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수정할 블록을 선택해 주세요.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(contributionRepositoryProvider).submit(
            widget.categorySlug,
            SubmitContributionRequest(
              targetBlockId: _editExistingMode ? _selectedBlockId : null,
              proposedBlockType: _blockType,
              proposedTitle: title,
              proposedBody: body,
              evidenceType: _evidenceEvent != null
                  ? 'EVENT_CARD'
                  : _evidenceReference != null
                      ? 'REFERENCE'
                      : null,
              evidenceTargetId: _evidenceEvent?.id ?? _evidenceReference?.id,
            ),
          );
      ref.invalidate(topicHubProvider(widget.categorySlug));
      ref.invalidate(myContributionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검수 요청이 등록되었습니다.')),
        );
        context.go('/categories/${widget.categorySlug}');
      }
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('제출 실패: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hubAsync = ref.watch(topicHubProvider(widget.categorySlug));

    // Pre-fill when we land with initialTargetBlockId and the hub data arrives.
    hubAsync.whenData((hub) {
      if (!_prefilledFromInitial && widget.initialTargetBlockId != null) {
        final block = hub.blocks.firstWhere(
          (b) => b.id == widget.initialTargetBlockId,
          orElse: () => hub.blocks.isNotEmpty
              ? hub.blocks.first
              : const KnowledgeBlockDto(
                  id: '', blockType: 'FAQ', title: '', body: '', sortOrder: 0),
        );
        if (block.id.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _prefillFromBlock(block);
          });
        }
        _prefilledFromInitial = true;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('정보 개선 제안'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/categories/${widget.categorySlug}'),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('검수 요청'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('카테고리: ${widget.categorySlug}',
              style: const TextStyle(color: PrismColors.muted)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('기존 블록 수정'),
                selected: _editExistingMode,
                onSelected: (_) => setState(() => _editExistingMode = true),
              ),
              ChoiceChip(
                label: const Text('새 블록 제안'),
                selected: !_editExistingMode,
                onSelected: (_) => _switchToNewMode(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_editExistingMode) ...[
            hubAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(
                e is ApiError ? e.message : '블록 목록을 불러오지 못했어요.',
                style: const TextStyle(color: Colors.redAccent),
              ),
              data: (hub) => DropdownButtonFormField<String>(
                initialValue: _selectedBlockId,
                decoration: const InputDecoration(
                  labelText: '수정할 블록',
                  border: OutlineInputBorder(),
                ),
                items: hub.blocks
                    .map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(
                              '${_kBlockTypes[b.blockType] ?? b.blockType} · ${b.title}'),
                        ))
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final block = hub.blocks.firstWhere((b) => b.id == id);
                  _prefillFromBlock(block);
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text('블록 유형', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kBlockTypes.entries
                .map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _blockType == e.key,
                      onSelected: (_) => setState(() => _blockType = e.key),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: '제목',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            maxLines: 8,
            minLines: 5,
            decoration: const InputDecoration(
              labelText: '본문',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('근거 (선택 — 한 가지만)',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _evidenceReference != null ? null : _pickEvent,
                  icon: const Icon(Icons.event),
                  label: Text(_evidenceEvent == null ? '이벤트 첨부' : '이벤트 변경'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _evidenceEvent != null ? null : _pickReference,
                  icon: const Icon(Icons.link),
                  label:
                      Text(_evidenceReference == null ? '레퍼런스 첨부' : '레퍼런스 변경'),
                ),
              ),
            ],
          ),
          if (_evidenceEvent != null) ...[
            const SizedBox(height: 10),
            Stack(
              children: [
                EventCardWidget(card: _evidenceEvent!, compact: true),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        setState(() => _evidenceEvent = null),
                    tooltip: '제거',
                  ),
                ),
              ],
            ),
          ],
          if (_evidenceReference != null) ...[
            const SizedBox(height: 10),
            Stack(
              children: [
                ReferenceCardWidget(
                    reference: _evidenceReference!, compact: true),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () =>
                        setState(() => _evidenceReference = null),
                    tooltip: '제거',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
