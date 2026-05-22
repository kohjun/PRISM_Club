import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/safe_route.dart';
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
    this.spaceSlug,
    this.returnTo,
  });

  final String categorySlug;
  final String? initialTargetBlockId;

  /// Forwarded from TopicHubScreen so cancel/submit lands back on the
  /// hub with the same back-fallback context. See
  /// `topic_hub_screen.dart:_composerRoute`.
  final String? spaceSlug;
  final String? returnTo;

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

  /// Builds the back-to-Topic-Hub URL preserving the spaceSlug +
  /// returnTo the hub passed us. Drops invalid returnTo values via
  /// [isSafeInternalRoute] so a malformed deep-link query can't slip
  /// through the round-trip.
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
        context.canPop() ? context.pop() : context.go(_hubUrl());
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
          tooltip: '닫기',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(_hubUrl()),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PrismSpacing.sm,
              vertical: 8,
            ),
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: PrismColors.pp600,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PrismRadius.pill),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '검수 요청',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          PrismSpacing.xl,
          PrismSpacing.lg,
          PrismSpacing.xl,
          PrismSpacing.xl4,
        ),
        children: [
          Text(
            '카테고리: ${widget.categorySlug}',
            style: const TextStyle(
              color: PrismColors.ink3,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: PrismSpacing.lg),
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
            decoration: const InputDecoration(labelText: '제목'),
          ),
          const SizedBox(height: PrismSpacing.md),
          TextField(
            controller: _body,
            maxLines: 8,
            minLines: 5,
            decoration: const InputDecoration(labelText: '본문'),
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
            const SizedBox(height: PrismSpacing.md),
            _EvidenceTile(
              child: EventCardWidget(
                card: _evidenceEvent!,
                compact: true,
              ),
              onRemove: () => setState(() => _evidenceEvent = null),
            ),
          ],
          if (_evidenceReference != null) ...[
            const SizedBox(height: PrismSpacing.md),
            _EvidenceTile(
              child: ReferenceCardWidget(
                reference: _evidenceReference!,
                compact: true,
              ),
              onRemove: () => setState(() => _evidenceReference = null),
            ),
          ],
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 24),
        ],
      ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.child, required this.onRemove});
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
          child: Semantics(
            button: true,
            label: '근거 제거',
            child: GestureDetector(
              onTap: onRemove,
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
          ),
        ),
      ],
    );
  }
}
